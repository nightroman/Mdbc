
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

using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.Builders;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.New, "MdbcUpdate")]
	public sealed class NewUpdateCommand : PSCmdlet
	{
		[Parameter]
		public PSObject[] AddToSet { get { return null; } set { _AddToSet = ToData(value); } }
		List<DictionaryEntry> _AddToSet;

		[Parameter]
		public PSObject[] AddToSetEach { get { return null; } set { _AddToSetEach = ToData(value); } }
		List<DictionaryEntry> _AddToSetEach;

		[Parameter]
		public PSObject[] BitwiseAnd { get { return null; } set { _BitwiseAnd = ToData(value); } }
		List<DictionaryEntry> _BitwiseAnd;

		[Parameter]
		public PSObject[] BitwiseOr { get { return null; } set { _BitwiseOr = ToData(value); } }
		List<DictionaryEntry> _BitwiseOr;

		[Parameter]
		public PSObject[] Inc { get { return null; } set { _Inc = ToData(value); } }
		List<DictionaryEntry> _Inc;

		[Parameter]
		public string[] PopFirst { get; set; }

		[Parameter]
		public string[] PopLast { get; set; }

		[Parameter]
		public PSObject[] Pull { get { return null; } set { _Pull = ToData(value); } }
		List<DictionaryEntry> _Pull;

		[Parameter]
		public PSObject[] PullAll { get { return null; } set { _PullAll = ToData(value); } }
		List<DictionaryEntry> _PullAll;

		[Parameter]
		public PSObject[] Push { get { return null; } set { _Push = ToData(value); } }
		List<DictionaryEntry> _Push;

		[Parameter]
		public PSObject[] PushAll { get { return null; } set { _PushAll = ToData(value); } }
		List<DictionaryEntry> _PushAll;

		[Parameter]
		public PSObject[] Rename { get { return null; } set { _Rename = ToData(value); } }
		List<DictionaryEntry> _Rename;

		[Parameter(Position = 0)]
		public PSObject[] Set { get { return null; } set { _Set = ToData(value); } }
		List<DictionaryEntry> _Set;

		[Parameter]
		public PSObject[] SetOnInsert { get { return null; } set { _SetOnInsert = ToData(value); } }
		List<DictionaryEntry> _SetOnInsert;

		[Parameter]
		public string[] Unset { get; set; }

		static List<DictionaryEntry> ToData(PSObject[] values)
		{
			var r = new List<DictionaryEntry>(values.Length);
			foreach (var po in values)
			{
				if (po == null)
					throw new PSInvalidOperationException("Null values are not allowed.");

				var dic = po.BaseObject as IDictionary;
				if (dic == null)
					throw new PSInvalidOperationException("Values must be dictionaries.");

				foreach (DictionaryEntry e in dic)
				{
					if (e.Key == null)
						throw new PSInvalidOperationException("Null keys are not allowed.");

					r.Add(e);
				}
			}
			return r;
		}

		protected sealed override void BeginProcessing()
		{
			UpdateBuilder r = new UpdateBuilder();

			if (_Set != null)
			{
				foreach (var e in _Set)
					r.Combine(Update.Set(e.Key.ToString(), Actor.ToBsonValue(e.Value)));
			}

			if (_SetOnInsert != null)
			{
				foreach (var e in _SetOnInsert)
					r.Combine(Update.SetOnInsert(e.Key.ToString(), Actor.ToBsonValue(e.Value)));
			}

			if (_BitwiseAnd != null)
			{
				foreach (var e in _BitwiseAnd)
				{
					var n = e.Key.ToString();
					var x = new IntLong(e.Value);
					r.Combine(x.Int.HasValue ? Update.BitwiseAnd(n, x.Int.Value) : Update.BitwiseAnd(n, x.Long.Value));
				}
			}

			if (_BitwiseOr != null)
			{
				foreach (var e in _BitwiseOr)
				{
					var n = e.Key.ToString();
					var x = new IntLong(e.Value);
					r.Combine(x.Int.HasValue ? Update.BitwiseOr(n, x.Int.Value) : Update.BitwiseOr(n, x.Long.Value));
				}
			}

			if (_Inc != null)
			{
				foreach (var e in _Inc)
				{
					var n = e.Key.ToString();
					var x = new IntLongDouble(e.Value);
					r.Combine(x.Int.HasValue ? Update.Inc(n, x.Int.Value) : x.Long.HasValue ? Update.Inc(n, x.Long.Value) : Update.Inc(n, x.Double.Value));
				}
			}

			if (_AddToSet != null)
			{
				foreach (var e in _AddToSet)
					r.Combine(Update.AddToSet(e.Key.ToString(), Actor.ToBsonValue(e.Value)));
			}

			if (_AddToSetEach != null)
			{
				foreach (var e in _AddToSetEach)
					r.Combine(Update.AddToSetEach(e.Key.ToString(), Actor.ToEnumerableBsonValue(e.Value)));
			}

			if (PopFirst != null)
			{
				foreach (var name in PopFirst)
					if (name != null)
						r.Combine(Update.PopFirst(name));
			}

			if (PopLast != null)
			{
				foreach (var name in PopLast)
					if (name != null)
						r.Combine(Update.PopLast(name));
			}

			if (_Pull != null)
			{
				foreach (var e in _Pull)
				{
					BsonValue value = null;
					IMongoQuery query = null;
					if (e.Value == null)
					{
						value = BsonNull.Value;
					}
					else
					{
						query = PSObject.AsPSObject(e.Value).BaseObject as IMongoQuery;
						if (query == null)
							value = Actor.ToBsonValue(e.Value);
					}

					var n = e.Key.ToString();
					r.Combine(query == null ? Update.Pull(n, value) : Update.Pull(n, query));
				}
			}

			if (_PullAll != null)
			{
				foreach (var e in _PullAll)
					r.Combine(Update.PullAll(e.Key.ToString(), Actor.ToEnumerableBsonValue(e.Value)));
			}

			if (_Push != null)
			{
				foreach (var e in _Push)
					r.Combine(Update.Push(e.Key.ToString(), Actor.ToBsonValue(e.Value)));
			}

			if (_PushAll != null)
			{
				foreach (var e in _PushAll)
					r.Combine(Update.PushAll(e.Key.ToString(), Actor.ToEnumerableBsonValue(e.Value)));
			}

			if (_Rename != null)
			{
				foreach (var e in _Rename)
				{
					if (e.Value == null)
						throw new PSInvalidOperationException("New names must not be nulls.");

					r.Combine(Update.Rename(e.Key.ToString(), e.Value.ToString()));
				}
			}

			if (Unset != null)
			{
				foreach (var name in Unset)
					if (name != null)
						r.Combine(Update.Unset(name));
			}

			WriteObject(r);
		}
	}
}
