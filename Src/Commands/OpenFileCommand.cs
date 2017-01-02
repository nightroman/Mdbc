
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Open, "MdbcFile")]
	public sealed class OpenFileCommand : Abstract
	{
		[Parameter(Position = 0)]
		public string Path { get; set; }

		[Parameter]
		[ValidateNotNull]
		public string CollectionVariable { get; set; }

		[Parameter]
		public SwitchParameter NewCollection { get; set; }

		[Parameter]
		public FileFormat FileFormat { get; set; }

		[Parameter]
		public SwitchParameter Simple { get; set; }

		protected override void BeginProcessing()
		{
			if (!string.IsNullOrEmpty(Path))
				Path = GetUnresolvedProviderPathFromPSPath(Path);

			FileCollection collection;
			if (Simple)
				collection = new SimpleFileCollection(Path, FileFormat);
			else
				collection = new NormalFileCollection(Path, FileFormat);

			collection.Read(NewCollection);

			SessionState.PSVariable.Set(CollectionVariable ?? Actor.CollectionVariable, collection);
		}
	}
}
