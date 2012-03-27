
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

using System.Collections.Generic;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.Builders;
namespace Mdbc.Commands
{
	public abstract class AbstractCollectionCommand : Cmdlet
	{
		[Parameter(Position = 0, Mandatory = true)]
		[ValidateNotNull]
		public MongoCollection Collection { get; set; }
	}
	public abstract class AbstractUpdate : PSCmdlet
	{
		[Parameter(Position = 0, Mandatory = true)]
		[ValidateNotNullOrEmpty]
		public string Name { get; set; }
	}
	public abstract class AbstractUpdatePSValue : AbstractUpdate
	{
		[Parameter(Position = 1)]
		public PSObject Value { get; set; }
	}
	public abstract class AbstractUpdateValue : AbstractUpdate
	{
		[Parameter(Position = 1, Mandatory = true)]
		public BsonValue Value { get; set; }
	}
	public abstract class AbstractUpdateValues : AbstractUpdate
	{
		[Parameter(Position = 1, Mandatory = true)]
		public PSObject Values { get; set; }
		protected IEnumerable<BsonValue> Enumerate()
		{
			return Actor.ToBsonValues(Values);
		}
	}
}
