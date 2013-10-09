
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
		const string nsAll = "All";
		const string nsAnd = "And";
		const string nsEQ = "EQ";
		const string nsExists = "Exists";
		const string nsGE = "GE";
		const string nsGT = "GT";
		const string nsIEQ = "IEQ";
		const string nsIn = "In";
		const string nsINE = "INE";
		const string nsLE = "LE";
		const string nsLT = "LT";
		const string nsMatch = "Match";
		const string nsMatches = "Matches";
		const string nsMod = "Mod";
		const string nsNE = "NE";
		const string nsNotIn = "NotIn";
		const string nsOr = "Or";
		const string nsSize = "Size";
		const string nsType = "Type";
		const string nsWhere = "Where";

		// `Not` is for all
		[Parameter]
		public SwitchParameter Not { get; set; }

		// `Name` is for all but binary
		[Parameter(Position = 0, ParameterSetName = nsAll)]
		[Parameter(Position = 0, ParameterSetName = nsEQ)]
		[Parameter(Position = 0, ParameterSetName = nsExists)]
		[Parameter(Position = 0, ParameterSetName = nsGE)]
		[Parameter(Position = 0, ParameterSetName = nsGT)]
		[Parameter(Position = 0, ParameterSetName = nsIEQ)]
		[Parameter(Position = 0, ParameterSetName = nsIn)]
		[Parameter(Position = 0, ParameterSetName = nsINE)]
		[Parameter(Position = 0, ParameterSetName = nsLE)]
		[Parameter(Position = 0, ParameterSetName = nsLT)]
		[Parameter(Position = 0, ParameterSetName = nsMatch)]
		[Parameter(Position = 0, ParameterSetName = nsMatches)]
		[Parameter(Position = 0, ParameterSetName = nsMod)]
		[Parameter(Position = 0, ParameterSetName = nsNE)]
		[Parameter(Position = 0, ParameterSetName = nsNotIn)]
		[Parameter(Position = 0, ParameterSetName = nsSize)]
		[Parameter(Position = 0, ParameterSetName = nsType)]
		[ValidateNotNullOrEmpty]
		public string Name { get; set; }

		#region [ Binary ]

		[Parameter(Mandatory = true, ParameterSetName = nsAnd)]
		public object[] And { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsOr)]
		public object[] Or { get; set; }

		#endregion
		#region [ Unary ]

		[Parameter(ParameterSetName = nsAll)]
		public PSObject All { get; set; }

		[Parameter(Position = 1, ParameterSetName = nsEQ)]
		public PSObject EQ { get; set; }

		[Parameter(ParameterSetName = nsExists)]
		public bool Exists { get; set; }

		[Parameter(ParameterSetName = nsGE)]
		public PSObject GE { get; set; }

		[Parameter(ParameterSetName = nsGT)]
		public PSObject GT { get; set; }

		[Parameter(ParameterSetName = nsIEQ)]
		public string IEQ { get; set; }

		[Parameter(ParameterSetName = nsIn)]
		public PSObject In { get; set; }

		[Parameter(ParameterSetName = nsINE)]
		public string INE { get; set; }

		[Parameter(ParameterSetName = nsLE)]
		public PSObject LE { get; set; }

		[Parameter(ParameterSetName = nsLT)]
		public PSObject LT { get; set; }

		[Parameter(ParameterSetName = nsMatch)]
		[ValidateCount(1, 2)]
		public PSObject[] Match { get; set; }

		[Parameter(ParameterSetName = nsMatches)]
		public PSObject Matches { get; set; }

		[Parameter(ParameterSetName = nsMod)]
		[ValidateCount(2, 2)]
		public int[] Mod { get; set; }

		[Parameter(ParameterSetName = nsNE)]
		public PSObject NE { get; set; }

		[Parameter(ParameterSetName = nsNotIn)]
		public PSObject NotIn { get; set; }

		[Parameter(ParameterSetName = nsSize)]
		public int Size { get; set; }

		[Parameter(ParameterSetName = nsType)]
		public BsonType Type { get; set; }

		[Parameter(ParameterSetName = nsWhere)]
		public string Where { get; set; }
		
		#endregion

		IMongoQuery NewMatchQuery()
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

			return Query.Matches(Name, bsonregex);
		}
		protected override void BeginProcessing()
		{
			IMongoQuery query;

			switch (ParameterSetName)
			{
				case nsAnd: query = Query.And(And.Select(Actor.ObjectToQuery)); break;
				case nsOr: query = Query.Or(Or.Select(Actor.ObjectToQuery)); break;
				case nsEQ: query = Query.EQ(Name, Actor.ToBsonValue(EQ, null)); break;
				case nsIEQ: query = Query.Matches(Name, new BsonRegularExpression("^" + Regex.Escape(IEQ) + "$", "i")); break;
				case nsINE: query = Query.Not(Query.Matches(Name, new BsonRegularExpression("^" + Regex.Escape(INE) + "$", "i"))); break;
				case nsLE: query = Query.LTE(Name, Actor.ToBsonValue(LE, null)); break;
				case nsLT: query = Query.LT(Name, Actor.ToBsonValue(LT, null)); break;
				case nsMatch: query = NewMatchQuery(); break;
				case nsNE: query = Query.NE(Name, Actor.ToBsonValue(NE, null)); break;
				case nsWhere: query = Query.Where(Where); break;
				case nsGE: query = Query.GTE(Name, Actor.ToBsonValue(GE, null)); break;
				case nsGT: query = Query.GT(Name, Actor.ToBsonValue(GT, null)); break;
				case nsExists: query = Exists ? Query.Exists(Name) : Query.NotExists(Name); break;
				case nsMod: query = Query.Mod(Name, Mod[0], Mod[1]); break;
				case nsSize: query = Query.Size(Name, Size); break;
				case nsType: query = Query.Type(Name, Type); break;
				case nsMatches: query = Query.ElemMatch(Name, Actor.ObjectToQuery(Matches)); break;
				case nsAll: query = Query.All(Name, Actor.ToEnumerableBsonValue(All)); break;
				case nsIn: query = Query.In(Name, Actor.ToEnumerableBsonValue(In)); break;
				case nsNotIn: query = Query.NotIn(Name, Actor.ToEnumerableBsonValue(NotIn)); break;
				default: return;
			}

			WriteObject(Not ? Query.Not(query) : query);
		}
	}
}
