
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsData.Import, "MdbcData")]
	public sealed class ImportDataCommand : Abstract
	{
		[Parameter(Position = 0, Mandatory = true)]
		public string Path { get; set; }

		[Parameter]
		public PSObject As { get { return null; } set { _ParameterAs = new ParameterAs(value); } }
		ParameterAs _ParameterAs;

		[Parameter]
		public FileFormat FileFormat { get; set; }

		protected override void BeginProcessing()
		{
			var documentAs = _ParameterAs ?? new ParameterAs(null);
			Path = GetUnresolvedProviderPathFromPSPath(Path);

			foreach (var doc in FileCollection.ReadDocumentsAs(documentAs.Type, Path, FileFormat))
				WriteObject(doc);
		}
	}
}
