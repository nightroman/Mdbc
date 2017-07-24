
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Diagnostics;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Management.Automation;
using System.Threading;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsData.Export, "MdbcData")]
	public sealed class ExportDataCommand : Abstract, IDisposable
	{
		[Parameter(Position = 0, Mandatory = true)]
		public string Path { get; set; }

		[Parameter(Position = 1, ValueFromPipeline = true)]
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
		public FileFormat FileFormat { get; set; }

		[Parameter]
		[ValidateCount(1, 2)]
		public TimeSpan[] Retry { get; set; }

		[Parameter]
		public SwitchParameter Append { get; set; }

		StreamWriter _streamWriter;
		FileStream _fileStream;
		BsonWriter _bsonWriter;

		public void Dispose()
		{
			if (_streamWriter != null)
			{
				_streamWriter.Close();
				_streamWriter = null;
			}

			if (_bsonWriter != null)
			{
				_bsonWriter.Close();
				_bsonWriter = null;
			}

			if (_fileStream != null)
			{
				_fileStream.Close();
				_fileStream = null;
			}
		}
		protected override void BeginProcessing()
		{
			Path = GetUnresolvedProviderPathFromPSPath(Path);

			if (FileFormat == FileFormat.Auto)
				FileFormat = Path.EndsWith(".json", StringComparison.OrdinalIgnoreCase) ? FileFormat.Json : FileFormat.Bson;

			var time = Stopwatch.StartNew();
			for (; ; )
			{
				try
				{
					if (FileFormat == FileFormat.Json)
					{
						_streamWriter = new StreamWriter(Path, Append);
					}
					else
					{
						_fileStream = File.Open(Path, (Append ? FileMode.Append : FileMode.Create));
						_bsonWriter = new BsonBinaryWriter(_fileStream);
					}
					break;
				}
				catch (IOException)
				{
					if (Retry == null || time.Elapsed > Retry[0])
						throw;

					if (Retry.Length < 2)
						Thread.Sleep(50);
					else
						Thread.Sleep(Retry[1]);

					WriteVerbose("Retrying to write...");
				}
			}
		}
		protected override void ProcessRecord()
		{
			if (InputObject == null)
				return;

			try
			{
				// new document or none yet
				var document = DocumentInput.NewDocumentWithId(NewId, Id, InputObject, SessionState);

				// document from input
				document = Actor.ToBsonDocument(document, InputObject, new DocumentInput(SessionState, Convert), _Selectors);

				// write
				if (FileFormat == FileFormat.Json)
				{
					using (var stringWriter = new StringWriter(CultureInfo.InvariantCulture))
					using (var jsonWriter = new JsonWriter(stringWriter, Actor.DefaultJsonWriterSettings))
					{
						BsonSerializer.Serialize(jsonWriter, document);
						_streamWriter.WriteLine(stringWriter.ToString());
					}
				}
				else
				{
					BsonSerializer.Serialize(_bsonWriter, document);
				}
			}
			catch (ArgumentException ex)
			{
				WriteError(DocumentInput.NewErrorRecordBsonValue(ex, InputObject));
			}
		}
	}
}
