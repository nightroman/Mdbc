
/* Copyright 2011-2014 Roman Kuzmin
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
