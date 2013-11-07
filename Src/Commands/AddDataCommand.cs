
/* Copyright 2011-2013 Roman Kuzmin
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

using System;
using System.Collections.Generic;
using System.Management.Automation;
using MongoDB.Driver;

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
