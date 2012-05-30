
/* Copyright 2011-2012 Roman Kuzmin
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
using MongoDB.Driver.Builders;
namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Add, "MdbcCollection")]
	public sealed class AddCollectionCommand : AbstractDatabaseCommand
	{
		[Parameter(Position = 0, Mandatory = true)]
		public string Name { get; set; }
		[Parameter]
		public long MaxSize { get; set; }
		[Parameter]
		public long MaxDocuments { get; set; }
		[Parameter]
		public bool? AutoIndexId { get; set; }
		protected override void BeginProcessing()
		{
			// default options
			var options = new CollectionOptionsBuilder();
			
			// capped collection
			if (MaxSize > 0)
			{
				options.SetCapped(true);
				options.SetMaxSize(MaxSize);
				if (MaxDocuments > 0)
					options.SetMaxDocuments(MaxDocuments);
			}
			
			// auto index explicitly
			if (AutoIndexId.HasValue)
				options.SetAutoIndexId(AutoIndexId.Value);
			
			Database.CreateCollection(Name, options);
		}
	}
}
