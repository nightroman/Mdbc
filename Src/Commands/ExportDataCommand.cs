
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
using MongoDB.Bson.Serialization.Serializers;

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
		public object[] Property { set { if (value == null) throw new PSArgumentNullException(nameof(value)); _Selectors = Selector.Create(value); } }
		IList<Selector> _Selectors;

		[Parameter]
		public FileFormat FileFormat { get; set; }

		[Parameter]
		[ValidateCount(1, 2)]
		public TimeSpan[] Retry { get; set; }

		[Parameter]
		public SwitchParameter Append { get; set; }

		BsonSerializationContext _context;
		BsonWriter _bsonWriter;
		Action _endDocument;
		Action _dispose;

		public void Dispose()
		{
			_bsonWriter?.Dispose();
			_dispose?.Invoke();
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
						StreamWriter streamWriter = null;
						try
						{
							streamWriter = new StreamWriter(Path, Append);
							_bsonWriter = new JsonWriter(streamWriter, Actor.DefaultJsonWriterSettings);
							_endDocument = () =>
							{
								streamWriter.WriteLine();
							};
						}
						finally
						{
							_dispose = () =>
							{
								streamWriter?.Dispose();
							};
						}
					}
					else
					{
						FileStream fileStream = null;
						try
						{
							fileStream = File.Open(Path, (Append ? FileMode.Append : FileMode.Create));
							_bsonWriter = new BsonBinaryWriter(fileStream);
						}
						finally
						{
							_dispose = () =>
							{
								fileStream?.Dispose();
							};
						}
					}
					_context = BsonSerializationContext.CreateRoot(_bsonWriter);
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
				var document = DocumentInput.NewDocumentWithId(NewId, Id, InputObject);

				// document from input
				document = Actor.ToBsonDocument(document, InputObject, Convert, _Selectors);

				// write
				BsonDocumentSerializer.Instance.Serialize(_context, document);
				_endDocument?.Invoke();
			}
			catch (ArgumentException ex)
			{
				WriteError(DocumentInput.NewErrorRecordBsonValue(ex, InputObject));
			}
		}
	}
}
