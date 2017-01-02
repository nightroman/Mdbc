
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsData.Save, "MdbcFile")]
	public sealed class SaveFileCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 0)]
		public string Path { get; set; }

		[Parameter]
		public FileFormat FileFormat { get; set; }

		protected override void BeginProcessing()
		{
			var fc = TargetCollection as FileCollection;
			if (fc != null)
				fc.Save(string.IsNullOrEmpty(Path) ? null : GetUnresolvedProviderPathFromPSPath(Path), FileFormat);
		}
	}
}
