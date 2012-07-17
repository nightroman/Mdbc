
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

using System.Linq;
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
		[Parameter(Mandatory = true, ParameterSetName = "And")]
		public object[] And { get; set; }
		[Parameter(Mandatory = true, ParameterSetName = "Or")]
		public object[] Or { get; set; }
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
		[ValidateCount(1, 2)]
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
		[ValidateCount(2, 2)]
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
			BsonRegularExpression bsonregex = null;
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
			}

			WriteObject(Not ? Query.Not(Query.Matches(Name, bsonregex)) : Query.Matches(Name, bsonregex));
		}
		protected override void BeginProcessing()
		{
			switch (ParameterSetName)
			{
				case "And":
					WriteObject(Query.And(And.Select(Actor.ObjectToQuery)));
					return;
				case "Or":
					WriteObject(Query.Or(Or.Select(Actor.ObjectToQuery)));
					return;
				case "EQ":
					WriteObject(Query.EQ(Name, Actor.ToBsonValue(EQ)));
					return;
				case "IEQ":
					WriteObject(Query.Matches(Name, new BsonRegularExpression("^" + Regex.Escape(IEQ) + "$", "i")));
					return;
				case "INE":
					WriteObject(Query.Not(Query.Matches(Name, new BsonRegularExpression("^" + Regex.Escape(INE) + "$", "i"))));
					return;
				case "Match":
					DoMatch();
					return;
				case "Where":
					WriteObject(Query.Where(Where));
					return;
			}

			IMongoQuery query = null;

			if (NE != null)
				query = Query.NE(Name, Actor.ToBsonValue(NE));
			else if (GE != null)
				query = Query.GTE(Name, Actor.ToBsonValue(GE));
			else if (GT != null)
				query = Query.GT(Name, Actor.ToBsonValue(GT));
			else if (LE != null)
				query = Query.LTE(Name, Actor.ToBsonValue(LE));
			else if (LT != null)
				query = Query.LT(Name, Actor.ToBsonValue(LT));
			else if (_existsSet)
				query = _exists ? Query.Exists(Name) : Query.NotExists(Name);
			else if (_sizeSet)
				query = Query.Size(Name, _size);
			else if (Type != 0)
				query = Query.Type(Name, Type);
			else if (Mod != null)
				query = Query.Mod(Name, Mod[0], Mod[1]);
			else if (Matches != null)
				query = Query.ElemMatch(Name, Actor.ObjectToQuery(Matches));
			else if (All != null)
				query = Query.All(Name, Actor.ToBsonValues(All));
			else if (In != null)
				query = Query.In(Name, Actor.ToBsonValues(In));
			else if (NotIn != null)
				query = Query.NotIn(Name, Actor.ToBsonValues(NotIn));

			WriteObject(Not ? Query.Not(query) : query);
		}
	}
}
