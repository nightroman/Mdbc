
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
using MongoDB.Driver;
using MongoDB.Driver.Builders;
namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.New, "MdbcUpdate")]
	public sealed class NewUpdateCommand : PSCmdlet
	{
		const string NAddToSet = "AddToSet";
		const string NAddToSetEach = "AddToSetEach";
		const string NBand = "Band";
		const string NBor = "Bor";
		const string NIncrement = "Increment";
		const string NPopFirst = "PopFirst";
		const string NPopLast = "PopLast";
		const string NPull = "Pull";
		const string NPullAll = "PullAll";
		const string NPush = "Push";
		const string NPushAll = "PushAll";
		const string NRename = "Rename";
		const string NSet = "Set";
		const string NSetOnInsert = "SetOnInsert";
		const string NUnset = "Unset";
		const string ExpectedInteger = "Invalid value type. Expected types: int, long.";
		const string ExpectedNumber = "Invalid value type. Expected types: int, long, double.";
		[Parameter(Position = 0, Mandatory = true)]
		public string Name { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NAddToSet)]
		public PSObject AddToSet { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NAddToSetEach)]
		public PSObject AddToSetEach { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NBand)]
		public PSObject Band { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NBor)]
		public PSObject Bor { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NIncrement)]
		public PSObject Increment { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NPopFirst)]
		public SwitchParameter PopFirst { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NPopLast)]
		public SwitchParameter PopLast { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NPull)]
		public PSObject Pull { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NPullAll)]
		public PSObject PullAll { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NPush)]
		public PSObject Push { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NPushAll)]
		public PSObject PushAll { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NRename)]
		public string Rename { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NSet)]
		[AllowNull]
		public PSObject Set { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NSetOnInsert)]
		[AllowNull]
		public PSObject SetOnInsert { get; set; }
		[Parameter(Position = 1, Mandatory = true, ParameterSetName = NUnset)]
		public SwitchParameter Unset { get; set; }
		UpdateBuilder BuildBand()
		{
			if (Band.BaseObject is int)
				return Update.BitwiseAnd(Name, (int)Band.BaseObject);

			if (Band.BaseObject is long)
				return Update.BitwiseAnd(Name, (long)Band.BaseObject);

			throw new PSInvalidCastException(ExpectedInteger);
		}
		UpdateBuilder BuildBor()
		{
			if (Bor.BaseObject is int)
				return Update.BitwiseOr(Name, (int)Bor.BaseObject);

			if (Bor.BaseObject is long)
				return Update.BitwiseOr(Name, (long)Bor.BaseObject);

			throw new PSInvalidCastException(ExpectedInteger);
		}
		UpdateBuilder BuildIncrement()
		{
			if (Increment.BaseObject is int)
				return Update.Inc(Name, (int)Increment.BaseObject);

			if (Increment.BaseObject is long)
				return Update.Inc(Name, (long)Increment.BaseObject);

			if (Increment.BaseObject is double)
				return Update.Inc(Name, (double)Increment.BaseObject);

			throw new PSInvalidCastException(ExpectedNumber);
		}
		UpdateBuilder BuildPull()
		{
			var query = Pull.BaseObject as IMongoQuery;
			if (query == null)
				return Update.Pull(Name, Actor.ToBsonValue(Pull));

			return Update.Pull(Name, query);
		}
		protected sealed override void BeginProcessing()
		{
			switch (ParameterSetName)
			{
				case NAddToSet:
					WriteObject(Update.AddToSet(Name, Actor.ToBsonValue(AddToSet)));
					return;

				case NAddToSetEach:
					WriteObject(Update.AddToSetEach(Name, Actor.ToBsonValues(AddToSetEach)));
					return;

				case NBand:
					WriteObject(BuildBand());
					return;

				case NBor:
					WriteObject(BuildBor());
					return;

				case NIncrement:
					WriteObject(BuildIncrement());
					return;

				case NPopFirst:
					WriteObject(Update.PopFirst(Name));
					return;

				case NPopLast:
					WriteObject(Update.PopLast(Name));
					return;

				case NPull:
					WriteObject(BuildPull());
					return;

				case NPullAll:
					WriteObject(Update.PullAll(Name, Actor.ToBsonValues(PullAll)));
					return;

				case NPush:
					WriteObject(Update.Push(Name, Actor.ToBsonValue(Push)));
					return;

				case NPushAll:
					WriteObject(Update.PushAll(Name, Actor.ToBsonValues(PushAll)));
					return;

				case NRename:
					WriteObject(Update.Rename(Name, Rename));
					return;

				case NSet:
					WriteObject(Update.Set(Name, Actor.ToBsonValue(Set)));
					return;

				case NSetOnInsert:
					WriteObject(Update.SetOnInsert(Name, Actor.ToBsonValue(SetOnInsert)));
					return;

				case NUnset:
					WriteObject(Update.Unset(Name));
					return;
			}
		}
	}
}
