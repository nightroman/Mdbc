
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Driver;
using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsOther.Use, "MdbcTransaction"), OutputType(typeof(IMongoDatabase))]
	public sealed class UseTransactionCommand : AbstractClientCommand
	{
		[Parameter(Position = 0, Mandatory = true)]
		public ScriptBlock Script { get; set; }

		protected override void BeginProcessing()
		{
			var session = Client.StartSession();
			AbstractSessionCommand.PushDefaultSession(session);
			try
			{
				session.StartTransaction();
				try
				{
					var vars = new List<PSVariable>() { new PSVariable("Session", session) };
					var result = Script.InvokeWithContext(null, vars);
					foreach (var item in result)
						WriteObject(item);

					session.CommitTransaction();
				}
				catch (RuntimeException exn)
				{
					var text = $"{exn.Message}{Environment.NewLine}{exn.ErrorRecord.InvocationInfo.PositionMessage}";
					var exn2 = new RuntimeException(text, exn);
					WriteException(exn2, null);
				}
			}
			finally
			{
				AbstractSessionCommand.PopDefaultSession();
				session.Dispose();
			}
		}
	}
}
