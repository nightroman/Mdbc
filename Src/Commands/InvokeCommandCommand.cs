
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsLifecycle.Invoke, "MdbcCommand"), OutputType(typeof(Dictionary))]
	public sealed class InvokeCommandCommand : AbstractDatabaseCommand
	{
		[Parameter(Position = 0)]
		public object Command { get { return null; } set { if (value != null) _Command = Api.Command(value); } }
		Command<BsonDocument> _Command;

		[Parameter]
		public PSObject As { get { return null; } set { _ParameterAs_ = new ParameterAs(value); } }
		Type DocumentType { get { return _ParameterAs_ == null ? typeof(Dictionary) : _ParameterAs_.Type; } }
		ParameterAs _ParameterAs_;

		protected override void BeginProcessing()
		{
			if (_Command == null) throw new PSArgumentException(Api.TextParameterCommand);
			try
			{
				var document = Database.RunCommand(_Command);
				var convert = Actor.ConvertDocument(DocumentType);
				WriteObject(convert(document));
			}
			catch (MongoCommandException ex)
			{
				WriteException(ex, null);
			}
		}
	}
}
