
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

using System.Collections.Generic;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsLifecycle.Invoke, "MdbcAggregate")]
	public sealed class InvokeAggregateCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 0, Mandatory = true)]
		public object Operation { get { return null; } set { _Operation = Actor.ObjectToBsonDocuments(value); } }
		IEnumerable<BsonDocument> _Operation;

		protected override void BeginProcessing()
		{
			var mc = TargetCollection.Collection as MongoCollection;
			if (mc == null) ThrowNotImplementedForFiles("Aggregate");

			var result = mc.Aggregate(_Operation);
			foreach (var document in result.ResultDocuments)
				WriteObject(new Dictionary(document));
		}
	}
}
