
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

using System.Collections;
using System.Linq;
using System.Management.Automation;
using MongoDB.Driver;
using MongoDB.Driver.Builders;
namespace Mdbc.Commands
{
	[Cmdlet(VerbsData.Update, "MdbcData")]
	public sealed class UpdateDataCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 1, Mandatory = true)]
		public PSObject Updates { get; set; }
		[Parameter(Position = 2, Mandatory = true, ValueFromPipeline = true)]
		public PSObject Query { get; set; }
		[Parameter]
		public UpdateFlags Modes { get; set; }
		[Parameter]
		public SafeMode SafeMode { get; set; }
		[Parameter]
		public SwitchParameter Safe { get; set; }
		static IMongoUpdate ToUpdate(PSObject value)
		{
			var update = value.BaseObject as IMongoUpdate;
			if (update != null)
				return update;

			var dictionary = value.BaseObject as IDictionary;
			if (dictionary != null)
				return new UpdateDocument(Actor.ToBsonDocument(dictionary, null));

			var enumerable = LanguagePrimitives.GetEnumerable(value.BaseObject);
			if (enumerable != null)
				return Update.Combine(enumerable.Cast<object>().Select(Actor.Cast<UpdateBuilder>));

			throw new PSInvalidCastException("Invalid update type. Valid types: update, dictionary.");
		}
		protected override void ProcessRecord()
		{
			var query = Actor.ObjectToQuery(Query);

			if (Safe)
				SafeMode = new SafeMode(Safe);

			var update = ToUpdate(Updates);

			SafeModeResult result = SafeMode == null ? Collection.Update(query, update, Modes) : Collection.Update(query, update, Modes, SafeMode);

			if (result != null)
				WriteObject(result);
		}
	}
}
