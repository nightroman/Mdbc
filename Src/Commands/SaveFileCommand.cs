
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

using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsData.Save, "MdbcFile")]
	public sealed class SaveFileCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 0)]
		public string Path { get; set; }
		
		protected override void BeginProcessing()
		{
			var fc = TargetCollection as FileCollection;
			if (fc != null)
				fc.Save(string.IsNullOrEmpty(Path) ? null : GetUnresolvedProviderPathFromPSPath(Path));
		}
	}
}
