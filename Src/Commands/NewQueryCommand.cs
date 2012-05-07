
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
using System.Text.RegularExpressions;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.Builders;
namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.New, "MdbcQuery")]
	public sealed class NewQueryCommand : PSCmdlet
	{
		const string ErrorAndNorOr = "-Or and -Nor switches cannot be used together.";
		[Parameter(Mandatory = true, ParameterSetName = "And")]
		public IMongoQuery[] And { get; set; }
		[Parameter(Mandatory = true, ParameterSetName = "Nor")]
		public IMongoQuery[] Nor { get; set; }
		[Parameter(Mandatory = true, ParameterSetName = "Or")]
		public IMongoQuery[] Or { get; set; }
		[Parameter(Position = 0, ParameterSetName = "EQ")]
		[Parameter(Position = 0, ParameterSetName = "IEQ")]
		[Parameter(Position = 0, ParameterSetName = "INE")]
		[Parameter(Position = 0, ParameterSetName = "Match")]
		[Parameter(Position = 0, ParameterSetName = "List")]
		[ValidateNotNullOrEmpty]
		public string Name { get; set; }
		#region [ One ]
		[Parameter(Position = 1, ParameterSetName = "EQ")]
		public PSObject EQ { get; set; }
		[Parameter(ParameterSetName = "IEQ")]
		public string IEQ { get; set; }
		[Parameter(ParameterSetName = "INE")]
		public string INE { get; set; }
		[Parameter(ParameterSetName = "Match")]
		public PSObject[] Match { get; set; }
		[Parameter(ParameterSetName = "Where")]
		public string Where { get; set; }
		#endregion
		#region [ List ]
		[Parameter(ParameterSetName = "Match")]
		[Parameter(ParameterSetName = "List")]
		public SwitchParameter Not { get; set; }
		[Parameter(ParameterSetName = "List")]
		public PSObject NE { get; set; }
		[Parameter(ParameterSetName = "List")]
		public PSObject GE { get; set; }
		[Parameter(ParameterSetName = "List")]
		public PSObject GT { get; set; }
		[Parameter(ParameterSetName = "List")]
		public PSObject LE { get; set; }
		[Parameter(ParameterSetName = "List")]
		public PSObject LT { get; set; }
		[Parameter(ParameterSetName = "List")]
		public bool Exists { get { return _exists; } set { _exists = value; _existsSet = true; } }
		bool _exists;
		bool _existsSet;
		[Parameter(ParameterSetName = "List")]
		public int Size { get { return _size; } set { _size = value; _sizeSet = true; } }
		int _size;
		bool _sizeSet;
		[Parameter(ParameterSetName = "List")]
		public BsonType Type { get; set; }
		[Parameter(ParameterSetName = "List")]
		public int[] Mod { get; set; }
		[Parameter(ParameterSetName = "List")]
		public PSObject Matches { get; set; }
		[Parameter(ParameterSetName = "List")]
		public PSObject All { get; set; }
		[Parameter(ParameterSetName = "List")]
		public PSObject In { get; set; }
		[Parameter(ParameterSetName = "List")]
		public PSObject NotIn { get; set; }
		#endregion
		void DoMatch()
		{
			BsonRegularExpression bsonregex;
			switch (Match.Length)
			{
				case 1:
					var text = Match[0].BaseObject as string;
					if (text != null)
					{
						bsonregex = new BsonRegularExpression(text);
						break;
					}

					var regex = Match[0].BaseObject as Regex;
					if (regex != null)
					{
						bsonregex = new BsonRegularExpression(regex);
						break;
					}

					throw new PSInvalidCastException("Invalid -Match argument.");

				case 2:
					var pattern = Match[0].BaseObject as string;
					var options = Match[1].BaseObject as string;
					if (pattern == null || options == null)
						throw new PSInvalidCastException("Invalid -Match argument.");

					bsonregex = new BsonRegularExpression(pattern, options);
					break;

				default:
					throw new PSInvalidOperationException("Expected one or two arguments for the -match parameter.");
			}

			WriteObject(Not ? Query.Not(Name).Matches(bsonregex) : Query.Matches(Name, bsonregex));
		}
		void DoList(QueryConditionList list)
		{
			if (NE != null)
				list = list.NE(Actor.ToBsonValue(NE));

			if (GE != null)
				list = list.GTE(Actor.ToBsonValue(GE));

			if (GT != null)
				list = list.GT(Actor.ToBsonValue(GT));

			if (LE != null)
				list = list.LTE(Actor.ToBsonValue(LE));

			if (LT != null)
				list = list.LT(Actor.ToBsonValue(LT));

			if (_existsSet)
				list = list.Exists(_exists);

			if (_sizeSet)
				list = list.Size(_size);

			if (Type != 0)
				list = list.Type(Type);

			if (Mod != null)
				list = list.Mod(Mod[0], Mod[1]);

			if (Matches != null)
				list = list.ElemMatch(Actor.ObjectToQuery(Matches));

			if (All != null)
				list = list.All(Actor.ToBsonValues(All));

			if (In != null)
				list = list.In(Actor.ToBsonValues(In));

			if (NotIn != null)
				list = list.NotIn(Actor.ToBsonValues(NotIn));

			WriteObject(list);
		}
		void DoListNot(QueryNotConditionList list)
		{
			if (NE != null)
				list = list.NE(Actor.ToBsonValue(NE));

			if (GE != null)
				list = list.GTE(Actor.ToBsonValue(GE));

			if (GT != null)
				list = list.GT(Actor.ToBsonValue(GT));

			if (LE != null)
				list = list.LTE(Actor.ToBsonValue(LE));

			if (LT != null)
				list = list.LT(Actor.ToBsonValue(LT));

			if (_existsSet)
				list = list.Exists(_exists);

			if (_sizeSet)
				list = list.Size(_size);

			if (Type != 0)
				list = list.Type(Type);

			if (Mod != null)
				list = list.Mod(Mod[0], Mod[1]);

			if (Matches != null)
				list = list.ElemMatch(Actor.ObjectToQuery(Matches));

			if (All != null)
				list = list.All(Actor.ToBsonValues(All));

			if (In != null)
				list = list.In(Actor.ToBsonValues(In));

			if (NotIn != null)
				list = list.NotIn(Actor.ToBsonValues(NotIn));

			WriteObject(list);
		}
		protected override void BeginProcessing()
		{
			switch (ParameterSetName)
			{
				case "And":
					WriteObject(Query.And(And));
					return;
				case "Nor":
					WriteObject(Query.Nor(Nor));
					return;
				case "Or":
					WriteObject(Query.Or(Or));
					return;
				case "EQ":
					WriteObject(Query.EQ(Name, Actor.ToBsonValue(EQ)));
					return;
				case "IEQ":
					WriteObject(Query.Matches(Name, new BsonRegularExpression("^" + Regex.Escape(IEQ) + "$", "i")));
					return;
				case "INE":
					WriteObject(Query.Not(Name).Matches(new BsonRegularExpression("^" + Regex.Escape(INE) + "$", "i")));
					return;
				case "Match":
					DoMatch();
					return;
				case "Where":
					WriteObject(Query.Where(Where));
					return;
			}

			if (Mod != null && Mod.Length != 2)
				throw new PSInvalidOperationException("The -Mod parameter must have two arguments.");

			if (Not)
				DoListNot(new QueryNotConditionList(Name));
			else
				DoList(new QueryConditionList(Name));
		}
	}
}
