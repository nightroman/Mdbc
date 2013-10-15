
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
using System.IO;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsData.Export, "MdbcData")]
	public sealed class ExportDataCommand : PSCmdlet, IDisposable
	{
		[Parameter(Position = 0, Mandatory = true)]
		public string Path { get; set; }
		
		[Parameter(ValueFromPipeline = true)]
		public PSObject InputObject { get; set; }
		
		[Parameter]
		public PSObject Id { get; set; }
		
		[Parameter]
		public SwitchParameter NewId { get; set; }
		
		[Parameter]
		public ScriptBlock Convert { get; set; }
		
		[Parameter]
		public object[] Property { get { return null; } set { _Selectors = Selector.Create(value, this); } }
		IList<Selector> _Selectors;
		
		[Parameter]
		public SwitchParameter Append { get; set; }
		
		FileStream _stream;
		BsonWriter _writer;
		
		public void Dispose()
		{
			if (_writer != null)
			{
				_writer.Close();
				_writer = null;
			}
			
			if (_stream != null)
			{
				_stream.Close();
				_stream = null;
			}
		}
		protected override void BeginProcessing()
		{
			Path = GetUnresolvedProviderPathFromPSPath(Path);
			_stream = File.Open(Path, (Append ? FileMode.Append : FileMode.Create));
			_writer = BsonWriter.Create(_stream);
		}
		protected override void ProcessRecord()
		{
			if (InputObject == null)
				return;

			try
			{
				// new document or none yet
				var document = DocumentInput.NewDocumentWithId(NewId, Id, InputObject, SessionState);
				
				document = Actor.ToBsonDocument(document, InputObject, new DocumentInput(SessionState, Convert), _Selectors);

				BsonSerializer.Serialize(_writer, document);
			}
			catch (ArgumentException ex)
			{
				WriteError(DocumentInput.NewErrorRecordBsonValue(ex, InputObject));
			}
		}
	}
}
