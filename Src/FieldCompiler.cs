
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

using System;
using System.Collections.Generic;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.Builders;

namespace Mdbc
{
	class FieldCompiler
	{
		readonly bool _All; // empty field document?
		readonly bool _Id = true; // it is set to false by Exclude(_id)
		readonly List<string> _Exclude; // it is either null or not empty, Exclude(_id) does not change it
		readonly List<string> _Include; // after Include(_id) it is empty and not null, this is important for null checks
		readonly Dictionary<string, int[]> _Slice = new Dictionary<string, int[]>();
		readonly Dictionary<string, Func<BsonDocument, bool>> _ElemMatch = new Dictionary<string, Func<BsonDocument, bool>>();
		static void ThrowMix() { throw new InvalidOperationException("You cannot currently mix including and excluding fields."); } //! DB text
		// Assume that keys are already unique, so we avoid many checks.
		FieldCompiler(IMongoFields fields)
		{
			var document = fields as BsonDocument;
			if (document == null)
			{
				var builder = fields as FieldsBuilder;
				if (builder == null)
					throw new InvalidCastException("Invalid field object type.");
				document = builder.ToBsonDocument();
			}

			if (document.ElementCount == 0)
			{
				_All = true;
				return;
			}

			foreach (var e in document)
			{
				var name = e.Name;
				var value = e.Value;
				if (value.IsNumeric)
				{
					if (e.Value.ToInt32() != 0)
					{
						// include
						if (_Exclude != null)
							ThrowMix();

						if (_Include == null)
							_Include = new List<string>();

						if (name != MyValue.Id)
							_Include.Add(name);
					}
					else
					{
						// exclude
						if (name == MyValue.Id)
						{
							_Id = false;
							continue;
						}

						if (_Include != null)
							ThrowMix();

						if (_Exclude == null)
							_Exclude = new List<string>();

						_Exclude.Add(name);
					}
					continue;
				}

				BsonDocument selector;
				if (value.BsonType != BsonType.Document || (selector = value.AsBsonDocument).ElementCount != 1)
					throw new InvalidOperationException("Invalid type of fields.");

				var element = selector.GetElement(0);
				var oper = element.Name;
				var arg = element.Value;

				// case slice
				if (oper == "$slice")
				{
					if (arg.IsNumeric)
					{
						_Slice.Add(name, new int[] { 0, arg.ToInt32() });
						continue;
					}

					BsonArray array;
					if (arg.BsonType != BsonType.Array || (array = arg.AsBsonArray).Count != 2)
						throw new InvalidOperationException("Invalid $slice argument.");

					int n = array[1].ToInt32();
					if (n <= 0)
						throw new InvalidOperationException("$slice limit must be positive."); //! DB text

					_Slice.Add(name, new int[] { array[0].ToInt32(), n });
					continue;
				}

				// case match

				if (oper != "$elemMatch")
					throw new InvalidOperationException("Invalid field operator.");

				if (arg.BsonType != BsonType.Document)
					throw new InvalidOperationException("Invalid field match argument.");

				_ElemMatch.Add(name, QueryCompiler.GetFunction(arg));
			}
		}
		BsonDocument Select(BsonDocument from)
		{
			BsonDocument to;
			if (_All || (_Include == null && _Exclude == null))
			{
				if (_Slice.Count == 0 && _ElemMatch.Count == 0)
					return from;

				to = new BsonDocument();
				foreach (var e in from)
					SliceOrElemMatch(e, to);
				return to;
			}

			to = new BsonDocument();

			if (_Id)
			{
				BsonValue v;
				if (from.TryGetValue(MyValue.Id, out v))
					to.Add(MyValue.Id, v);
			}

			if (_Include != null)
			{
				foreach (var name in _Include)
				{
					BsonValue v;
					if (from.TryGetValue(name, out v))
						to.Add(name, v);
				}
				foreach (var e in _Slice)
				{
					BsonValue a;
					if (from.TryGetValue(e.Key, out a) && a.BsonType == BsonType.Array)
						to.Add(e.Key, a.AsBsonArray.Slice(e.Value));
				}
				foreach (var e in _ElemMatch)
				{
					BsonValue a, match;
					if (from.TryGetValue(e.Key, out a) && a.BsonType == BsonType.Array && (match = ElemMatch(a.AsBsonArray, e.Value)) != null)
						to.Add(e.Key, match);
				}
			}
			else
			{
				// all but exclude and slice or match
				foreach (var e in from)
					if (e.Name != MyValue.Id && !_Exclude.Contains(e.Name))
						SliceOrElemMatch(e, to);
			}

			return to;
		}
		bool NeedsAlienField(string name)
		{
			if (_ElemMatch.Count == 0)
				return true;

			if (_Exclude != null)
				return true;

			return _Id && name == MyValue.Id;
		}
		void SliceOrElemMatch(BsonElement from, BsonDocument to)
		{
			if (from.Value.BsonType != BsonType.Array)
			{
				if (_Exclude != null && _ElemMatch.ContainsKey(from.Name)) //_131103_173143
					return;
				if (NeedsAlienField(from.Name))
					to.Add(from);
				return;
			}

			int[] slice;
			BsonValue value;
			Func<BsonDocument, bool> match;

			if (_Slice.TryGetValue(from.Name, out slice))
				to.Add(from.Name, from.Value.AsBsonArray.Slice(slice));
			else if (_ElemMatch.TryGetValue(from.Name, out match) && (value = ElemMatch(from.Value.AsBsonArray, match)) != null)
				to.Add(from.Name, new BsonArray() { value });
			else if (NeedsAlienField(from.Name))
				to.Add(from);
		}
		static BsonValue ElemMatch(BsonArray array, Func<BsonDocument, bool> predicate)
		{
			foreach (var v in array)
				if (v.BsonType == BsonType.Document && predicate(v.AsBsonDocument))
					return v;
			return null;
		}
		internal static Func<BsonDocument, BsonDocument> GetFunction(IMongoFields fields)
		{
			var compiler = new FieldCompiler(fields);
			return compiler.Select;
		}
	}
}
