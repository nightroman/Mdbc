
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
		public SwitchParameter Simple { get; set; }

		protected override void BeginProcessing()
		{
			if (!string.IsNullOrEmpty(Path))
				Path = GetUnresolvedProviderPathFromPSPath(Path);
			
			FileCollection collection;
			if (Simple)
				collection = new SimpleFileCollection(Path);
			else
				collection = new NormalFileCollection(Path);

			collection.Read(NewCollection);

			SessionState.PSVariable.Set(CollectionVariable ?? Actor.CollectionVariable, collection);
		}
	}
}
