
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using System.Management.Automation;

namespace Mdbc.Commands;

[Cmdlet(VerbsData.Import, "MdbcData")]
public sealed class ImportDataCommand : Abstract
{
	[Parameter(Position = 0, Mandatory = true)]
	public string Path { get; set; }

	[Parameter]
	public object As { set { _As.Set(value); } }
	readonly ParameterAs _As = new();

	[Parameter]
	public FileFormat FileFormat { get; set; }

	protected override void BeginProcessing()
	{
		Path = GetUnresolvedProviderPathFromPSPath(Path);

		foreach (var doc in ReadDocumentsAs(_As.Type, Path, FileFormat))
			WriteObject(doc);
	}

	static IEnumerable<object> ReadDocumentsAs(Type documentType, string filePath, FileFormat format)
	{
		if (format == FileFormat.Auto)
			format = filePath.EndsWith(".json", StringComparison.OrdinalIgnoreCase) ? FileFormat.Json : FileFormat.Bson;

		var serializer = BsonSerializer.LookupSerializer(documentType);
		if (format == FileFormat.Bson)
		{
			using var stream = File.OpenRead(filePath);
			using var reader = new BsonBinaryReader(stream);
			var context = BsonDeserializationContext.CreateRoot(reader);
			long length = stream.Length;
			while (stream.Position < length)
				yield return serializer.Deserialize(context);
		}
		else
		{
			using var stream = File.OpenText(filePath);
			using var reader = new JsonReader(stream);
			var context = BsonDeserializationContext.CreateRoot(reader);
			while (!reader.IsAtEndOfFile())
				yield return serializer.Deserialize(context);
		}
	}
}
