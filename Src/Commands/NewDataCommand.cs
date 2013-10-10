
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
	[Cmdlet(VerbsCommon.New, "MdbcData", DefaultParameterSetName = NDocument)]
	public sealed class NewDataCommand : PSCmdlet, IDocumentInput
	{
		const string NDocument = "Document";
		const string NValue = "Value";
		
		[Parameter(ParameterSetName = NValue)]
		public PSObject Value { get; set; }
		
		[Parameter(Position = 0, ValueFromPipeline = true, ParameterSetName = NDocument)]
		public PSObject InputObject { get; set; }
		
		[Parameter(ParameterSetName = NDocument)]
		public PSObject Id { get; set; }
		
		[Parameter(ParameterSetName = NDocument)]
		public SwitchParameter NewId { get; set; }
		
		[Parameter(ParameterSetName = NDocument)]
		public ScriptBlock Convert { get; set; }
		
		[Parameter(ParameterSetName = NDocument)]
		public object[] Property { get { return null; } set { _Selectors = Selector.Create(value, this); } }
		IList<Selector> _Selectors;
		
		void WriteDocument(BsonDocument document)
		{
			DocumentInput.MakeId(document, this, SessionState);
			WriteObject(new Dictionary(document));
		}
		protected override void ProcessRecord()
		{
			try
			{
				if (ParameterSetName == NValue)
					WriteObject(Actor.ToBsonValue(Value));
				else if (InputObject == null)
					WriteDocument(new BsonDocument());
				else
					WriteDocument(Actor.ToBsonDocument(InputObject, new DocumentInput(SessionState, Convert), _Selectors));
			}
			catch (ArgumentException ex)
			{
				WriteError(DocumentInput.NewErrorRecordBsonValue(ex, InputObject));
			}
		}
	}
}
