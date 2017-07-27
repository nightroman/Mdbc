
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Driver;
using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace Mdbc.Commands
{
    [Cmdlet(VerbsCommon.Add, "MdbcData")]
	public sealed class AddDataCommand : AbstractWriteCommand
	{
		[Parameter(Position = 0, ValueFromPipeline = true)]
		public PSObject InputObject { get; set; }

		[Parameter]
		public SwitchParameter Update { get; set; }

		[Parameter]
		public PSObject Id { get; set; }

		[Parameter]
		public SwitchParameter NewId { get; set; }

		[Parameter]
		public ScriptBlock Convert { get; set; }

		[Parameter]
		public object[] Property { get { return null; } set { _Selectors = Selector.Create(value, this); } }
		IList<Selector> _Selectors;

		protected override void ProcessRecord()
		{
			if (InputObject == null)
				return;

			try
			{
				// new document or none yet
				var document = DocumentInput.NewDocumentWithId(NewId, Id, InputObject, SessionState);

				document = Actor.ToBsonDocument(document, InputObject, new DocumentInput(SessionState, Convert), _Selectors);

				if (Update)
					WriteResult(TargetCollection.Save(document, WriteConcern, Result));
				else
					WriteResult(TargetCollection.Insert(document, WriteConcern, Result));
			}
			catch (ArgumentException ex)
			{
				WriteError(DocumentInput.NewErrorRecordBsonValue(ex, InputObject));
			}
            catch (MongoException ex)
            {
                WriteException(ex, InputObject);
            }
        }
    }
}
