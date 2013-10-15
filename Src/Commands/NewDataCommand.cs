
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
using MongoDB.Bson;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.New, "MdbcData", DefaultParameterSetName = nsDocument)]
	public sealed class NewDataCommand : PSCmdlet
	{
		const string nsDocument = "Document";
		const string nsValue = "Value";
		
		[Parameter(ParameterSetName = nsValue)]
		public PSObject Value { get; set; }
		
		[Parameter(Position = 0, ValueFromPipeline = true, ParameterSetName = nsDocument)]
		public PSObject InputObject { get; set; }
		
		[Parameter(ParameterSetName = nsDocument)]
		public PSObject Id { get; set; }
		
		[Parameter(ParameterSetName = nsDocument)]
		public SwitchParameter NewId { get; set; }
		
		[Parameter(ParameterSetName = nsDocument)]
		public ScriptBlock Convert { get; set; }
		
		[Parameter(ParameterSetName = nsDocument)]
		public object[] Property { get { return null; } set { _Selectors = Selector.Create(value, this); } }
		IList<Selector> _Selectors;
		
		protected override void ProcessRecord()
		{
			try
			{
				if (ParameterSetName == nsValue)
				{
					WriteObject(Actor.ToBsonValue(Value));
					return;
				}
				
				// always new document
				var document = DocumentInput.NewDocumentWithId(NewId, Id, InputObject, SessionState) ?? new BsonDocument();
				
				if (InputObject != null)
					document = Actor.ToBsonDocument(document, InputObject, new DocumentInput(SessionState, Convert), _Selectors);

				WriteObject(new Dictionary(document));
			}
			catch (ArgumentException ex)
			{
				WriteError(DocumentInput.NewErrorRecordBsonValue(ex, InputObject));
			}
		}
	}
}
