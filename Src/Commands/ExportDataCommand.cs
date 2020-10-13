
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Serializers;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Management.Automation;
using System.Threading;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsData.Export, "MdbcData")]
	public sealed class ExportDataCommand : Abstract, IDisposable
	{
		[Parameter(Position = 0, Mandatory = true)]
		public string Path { get; set; }

		[Parameter(Position = 1, ValueFromPipeline = true)]
		public object InputObject { get; set; }

		[Parameter]
		public object Id { get; set; }

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

		static FileFormat ResolveFileFormat(FileFormat fileFormat, string path)
		{
			if (fileFormat != FileFormat.Auto)
				return fileFormat;
			if (path.EndsWith(".JSON", StringComparison.Ordinal))
				return FileFormat.JsonStrict;
			if (path.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
				return FileFormat.JsonShell;
			return FileFormat.Bson;
		}

		protected override void BeginProcessing()
		{
			FileFormat = ResolveFileFormat(FileFormat, Path);
			Path = GetUnresolvedProviderPathFromPSPath(Path);

			var time = Stopwatch.StartNew();
			for (; ; )
			{
				try
				{
					if (FileFormat == FileFormat.Bson)
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
					else
					{
						StreamWriter streamWriter = null;
						try
						{
							var settings = JsonWriterSettings.Defaults;
							switch (FileFormat)
							{
								case FileFormat.JsonShell:
									settings = settings.Clone();
									settings.OutputMode = JsonOutputMode.Shell;
									break;
								case FileFormat.JsonStrict:
									settings = settings.Clone();
#pragma warning disable 618 // obsolete JsonOutputMode.Strict
									settings.OutputMode = JsonOutputMode.Strict;
#pragma warning restore 618
									break;
								case FileFormat.JsonCanonicalExtended:
									settings = settings.Clone();
									settings.OutputMode = JsonOutputMode.CanonicalExtendedJson;
									break;
								case FileFormat.JsonRelaxedExtended:
									settings = settings.Clone();
									settings.OutputMode = JsonOutputMode.RelaxedExtendedJson;
									break;
							}

							streamWriter = new StreamWriter(Path, Append);
							_bsonWriter = new JsonWriter(streamWriter, settings);
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
