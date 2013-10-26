
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
		const string nsElemMatch = "ElemMatch";
		const string nsEQ = "EQ";
		const string nsExists = "Exists";
		const string nsGT = "GT";
		const string nsGTE = "GTE";
		const string nsIEQ = "IEQ";
		const string nsIn = "In";
		const string nsINE = "INE";
		const string nsLT = "LT";
		const string nsLTE = "LTE";
		const string nsMatches = "Matches";
		const string nsMod = "Mod";
		const string nsNE = "NE";
		const string nsNot = "Not";
		const string nsNotExists = "NotExists";
		const string nsNotIn = "NotIn";
		const string nsOr = "Or";
		const string nsSize = "Size";
		const string nsType = "Type";
		const string nsWhere = "Where";

		// Name is for all but unary and binary
		[Parameter(Position = 0, ParameterSetName = nsAll)]
		[Parameter(Position = 0, ParameterSetName = nsElemMatch)]
		[Parameter(Position = 0, ParameterSetName = nsEQ)]
		[Parameter(Position = 0, ParameterSetName = nsExists)]
		[Parameter(Position = 0, ParameterSetName = nsGT)]
		[Parameter(Position = 0, ParameterSetName = nsGTE)]
		[Parameter(Position = 0, ParameterSetName = nsIEQ)]
		[Parameter(Position = 0, ParameterSetName = nsIn)]
		[Parameter(Position = 0, ParameterSetName = nsINE)]
		[Parameter(Position = 0, ParameterSetName = nsLT)]
		[Parameter(Position = 0, ParameterSetName = nsLTE)]
		[Parameter(Position = 0, ParameterSetName = nsMatches)]
		[Parameter(Position = 0, ParameterSetName = nsMod)]
		[Parameter(Position = 0, ParameterSetName = nsNE)]
		[Parameter(Position = 0, ParameterSetName = nsNotExists)]
		[Parameter(Position = 0, ParameterSetName = nsNotIn)]
		[Parameter(Position = 0, ParameterSetName = nsSize)]
		[Parameter(Position = 0, ParameterSetName = nsType)]
		[ValidateNotNullOrEmpty]
		public string Name { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsAnd)]
		public object[] And { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsAll)]
		public PSObject All { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsElemMatch)]
		public PSObject ElemMatch { get; set; }

		[Parameter(Position = 1, Mandatory = true, ParameterSetName = nsEQ)]
		[AllowNull]
		public PSObject EQ { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsExists)]
		public SwitchParameter Exists { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsGT)]
		[AllowNull]
		public PSObject GT { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsGTE)]
		[AllowNull]
		public PSObject GTE { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsIEQ)]
		public string IEQ { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsIn)]
		public PSObject In { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsINE)]
		public string INE { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsLT)]
		[AllowNull]
		public PSObject LT { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsLTE)]
		[AllowNull]
		public PSObject LTE { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsMatches)]
		[ValidateCount(1, 2)]
		public PSObject[] Matches { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsMod)]
		[ValidateCount(2, 2)]
		public long[] Mod { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsNE)]
		[AllowNull]
		public PSObject NE { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsNot)]
		public object Not { get { return null; } set { _Not = Actor.ObjectToQuery(value); } }
		IMongoQuery _Not;

		[Parameter(Mandatory = true, ParameterSetName = nsNotExists)]
		public SwitchParameter NotExists { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsNotIn)]
		public PSObject NotIn { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsOr)]
		public object[] Or { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsSize)]
		public int Size { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsType)]
		public BsonType Type { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsWhere)]
		public string Where { get; set; }

		IMongoQuery NewMatchQuery()
		{
			BsonRegularExpression bsonregex = null;
			switch (Matches.Length)
			{
				case 1:
					var text = Matches[0].BaseObject as string;
					if (text != null)
					{
						bsonregex = new BsonRegularExpression(text);
						break;
					}

					var regex = Matches[0].BaseObject as Regex;
					if (regex != null)
					{
						bsonregex = new BsonRegularExpression(regex);
						break;
					}

					throw new PSInvalidCastException("Invalid -Match argument.");

				case 2:
					var pattern = Matches[0].BaseObject as string;
					var options = Matches[1].BaseObject as string;
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
				case nsAll: query = Query.All(Name, Actor.ToEnumerableBsonValue(All)); break;
				case nsAnd: query = Query.And(And.Select(Actor.ObjectToQuery)); break;
				case nsElemMatch: query = Query.ElemMatch(Name, Actor.ObjectToQuery(ElemMatch)); break;
				case nsEQ: query = Query.EQ(Name, Actor.ToBsonValue(EQ)); break;
				case nsExists: query = Exists ? Query.Exists(Name) : Query.NotExists(Name); break;
				case nsGT: query = Query.GT(Name, Actor.ToBsonValue(GT)); break;
				case nsGTE: query = Query.GTE(Name, Actor.ToBsonValue(GTE)); break;
				case nsIEQ: query = Query.Matches(Name, new BsonRegularExpression("^" + Regex.Escape(IEQ) + "$", "i")); break;
				case nsIn: query = Query.In(Name, Actor.ToEnumerableBsonValue(In)); break;
				case nsINE: query = Query.Not(Query.Matches(Name, new BsonRegularExpression("^" + Regex.Escape(INE) + "$", "i"))); break;
				case nsLT: query = Query.LT(Name, Actor.ToBsonValue(LT)); break;
				case nsLTE: query = Query.LTE(Name, Actor.ToBsonValue(LTE)); break;
				case nsMatches: query = NewMatchQuery(); break;
				case nsMod: query = Query.Mod(Name, Mod[0], Mod[1]); break;
				case nsNE: query = Query.NE(Name, Actor.ToBsonValue(NE)); break;
				case nsNot: query = Query.Not(_Not); break;
				case nsNotExists: query = NotExists ? Query.NotExists(Name) : Query.Exists(Name); break;
				case nsNotIn: query = Query.NotIn(Name, Actor.ToEnumerableBsonValue(NotIn)); break;
				case nsOr: query = Query.Or(Or.Select(Actor.ObjectToQuery)); break;
				case nsSize: query = Query.Size(Name, Size); break;
				case nsType: query = Query.Type(Name, Type); break;
				case nsWhere: query = Query.Where(Where); break;
				default: return;
			}

			WriteObject(query);
		}
	}
}
