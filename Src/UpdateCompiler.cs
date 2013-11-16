
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
using System.Linq;
using System.Linq.Expressions;
using System.Management.Automation;
using System.Reflection;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.Builders;

namespace Mdbc
{
	public class UpdateCompiler
	{
		#region Operators
		static Expression AddToSetExpression(Expression that, Expression field, BsonValue value)
		{
			bool addEach = false;
			if (value.BsonType == BsonType.Document)
			{
				var d = value.AsBsonDocument;
				if (d.ElementCount == 1)
				{
					var e = d.ElementAt(0);
					if (e.Name == "$each")
					{
						addEach = true;
						value = e.Value;
					}
				}
			}
			return Expression.Call(that, GetMethod("AddToSet"), Data, field, Expression.Constant(value, typeof(BsonValue)), Expression.Constant(addEach, typeof(bool)));
		}
		UpdateCompiler AddToSet(BsonDocument document, string name, BsonValue value, bool each)
		{
			var r = document.EnsurePath(name);

			BsonValue vArray;
			if (r.Array != null)
			{
				if (r.Array.InsertOutOfRange(r.Index, () => new BsonArray() { value }))
					return this;

				vArray = r.Array[r.Index];
			}
			else if (!r.Document.TryGetValue(r.Key, out vArray))
			{
				r.Document.Add(r.Key, new BsonArray() { value });
				return this;
			}

			if (vArray.BsonType != BsonType.Array)
				throw new InvalidOperationException(string.Format(null, @"Value ""{0}"" must be array.", name));

			if (each && value.BsonType == BsonType.Array)
				vArray.AsBsonArray.AddToSetEach(value.AsBsonArray);
			else
				vArray.AsBsonArray.AddToSet(value);

			return this;
		}
		static Expression BitwiseExpression(Expression that, Expression field, BsonValue value)
		{
			if (value == null || value.BsonType != BsonType.Document)
				throw new ArgumentException("Bitwise value must be document.");

			var d = value.AsBsonDocument;
			if (d.ElementCount != 1)
				throw new ArgumentException("Bitwise value must have one element.");

			var e = d.GetElement(0);
			var v = e.Value;
			if (v.BsonType != BsonType.Int32 && v.BsonType != BsonType.Int64)
				throw new ArgumentException("Bitwise value must be Int32 or Int64.");

			switch (e.Name)
			{
				case "and":
					return Expression.Call(that, GetMethod("BitwiseAnd"), Data, field, Expression.Constant(v, typeof(BsonValue)));
				case "or":
					return Expression.Call(that, GetMethod("BitwiseOr"), Data, field, Expression.Constant(v, typeof(BsonValue)));
				default:
					throw new ArgumentException(@"Bitwise value element name must be ""and"" or ""or"".");
			}
		}
		static void Bitwise(BsonDocument document, string name, BsonValue value, bool and)
		{
			var r = document.ResolvePath(name);
			if (r == null)
				return;

			BsonValue old;
			if (r.Array != null)
			{
				old = r.Array[r.Index];
				if (old.BsonType != BsonType.Int32 && old.BsonType != BsonType.Int64)
					throw new MongoException(string.Format(null, @"Item ""{0}"" must be Int32 or Int64.", name));

				r.Array[r.Index] = and ? MyValue.BitwiseAnd(old, value) : MyValue.BitwiseOr(old, value);
			}
			else if (r.Document.TryGetValue(r.Key, out old))
			{
				if (old.BsonType != BsonType.Int32 && old.BsonType != BsonType.Int64)
					throw new MongoException(string.Format(null, @"Field ""{0}"" must be Int32 or Int64.", name));

				r.Document[r.Key] = and ? MyValue.BitwiseAnd(old, value) : MyValue.BitwiseOr(old, value);
			}
		}
		UpdateCompiler BitwiseAnd(BsonDocument document, string name, BsonValue value)
		{
			Bitwise(document, name, value, true);
			return this;
		}
		UpdateCompiler BitwiseOr(BsonDocument document, string name, BsonValue value)
		{
			Bitwise(document, name, value, false);
			return this;
		}
		static Expression IncExpression(Expression that, Expression field, BsonValue value)
		{
			if (value == null || !value.IsNumeric)
				throw new ArgumentException("Increment value must be numeric.");

			return Expression.Call(that, GetMethod("Inc"), Data, field, Expression.Constant(value, typeof(BsonValue)));
		}
		UpdateCompiler Inc(BsonDocument document, string name, BsonValue value)
		{
			var r = document.EnsurePath(name);
			BsonValue old;
			if (r.Document != null)
			{
				if (r.Document.TryGetValue(r.Key, out old))
				{
					if (!old.IsNumeric)
						throw new MongoException(string.Format(null, @"Field ""{0}"" must be numeric.", name));

					value = MyValue.Add(old, value);
				}

				r.Document[r.Key] = value;
			}
			else if (!r.Array.InsertOutOfRange(r.Index, () => value))
			{
				old = r.Array[r.Index];
				if (!old.IsNumeric)
					throw new MongoException(string.Format(null, @"Item ""{0}"" must be numeric.", name));

				r.Array[r.Index] = MyValue.Add(old, value);
			}
			return this;
		}
		static Expression PopExpression(Expression that, Expression field, BsonValue value)
		{
			int pop = value.IsNumeric ? value.ToInt32() : 0;
			return Expression.Call(that, GetMethod("Pop"), Data, field, Expression.Constant(pop, typeof(int)));
		}
		UpdateCompiler Pop(BsonDocument document, string name, int value)
		{
			var r = document.ResolvePath(name);
			if (r == null)
				return this;

			BsonValue vArray;
			if (r.Array != null)
			{
				vArray = r.Array[r.Index];
			}
			else if (!r.Document.TryGetValue(r.Key, out vArray))
			{
				return this;
			}

			if (vArray.BsonType != BsonType.Array)
				throw new InvalidOperationException(string.Format(null, @"Value ""{0}"" must be array.", name));

			var array = vArray.AsBsonArray;
			if (array.Count > 0)
			{
				if (value < 0)
					array.RemoveAt(0);
				else
					array.RemoveAt(array.Count - 1);
			}

			return this;
		}
		static void Pull(BsonDocument document, string name, BsonValue value, bool all)
		{
			var r = document.ResolvePath(name);
			if (r == null)
				return;

			BsonValue vArray;
			if (r.Array != null)
				vArray = r.Array[r.Index];
			else if (!r.Document.TryGetValue(r.Key, out vArray))
				return;

			if (vArray.BsonType != BsonType.Array)
				throw new InvalidOperationException(string.Format(null, @"Value ""{0}"" must be array.", name));

			var array = vArray.AsBsonArray;
			if (!all && value.BsonType == BsonType.Document)
			{
				var predicate = QueryCompiler.GetFunction(value);
				for (int i = array.Count; --i >= 0; )
				{
					var v = array[i];
					if (v.BsonType == BsonType.Document && predicate(v.AsBsonDocument))
						array.RemoveAt(i);
				}
			}
			else
			{
				BsonArray values = all ? value.AsBsonArray : null;
				for (int i = array.Count; --i >= 0; )
				{
					if (values == null)
					{
						if (value.CompareTo(array[i]) == 0)
							array.RemoveAt(i);
					}
					else
					{
						if (values.ContainsByCompareTo(array[i]))
							array.RemoveAt(i);
					}
				}
			}
		}
		static Expression PullExpression(Expression that, Expression field, BsonValue value)
		{
			return Expression.Call(that, GetMethod("Pull"), Data, field, Expression.Constant(value, typeof(BsonValue)));
		}
		UpdateCompiler Pull(BsonDocument document, string name, BsonValue value)
		{
			Pull(document, name, value, false);
			return this;
		}
		static Expression PullAllExpression(Expression that, Expression field, BsonValue value)
		{
			if (value.BsonType != BsonType.Array)
				throw new ArgumentException("Pull all value must be array.");

			return Expression.Call(that, GetMethod("PullAll"), Data, field, Expression.Constant(value, typeof(BsonValue)));
		}
		UpdateCompiler PullAll(BsonDocument document, string name, BsonValue value)
		{
			Pull(document, name, value, true);
			return this;
		}
		static void Push(BsonDocument document, string name, BsonValue value, bool all)
		{
			var r = document.EnsurePath(name);

			BsonValue v2 = BsonNull.Value;
			if (r.Array != null)
			{
				if (!r.Array.InsertOutOfRange(r.Index, () => v2 = new BsonArray()))
					v2 = r.Array[r.Index];
			}
			else if (!r.Document.TryGetValue(r.Key, out v2))
			{
				v2 = new BsonArray();
				r.Document.Add(r.Key, v2);
			}

			if (v2.BsonType != BsonType.Array)
				throw new InvalidOperationException(string.Format(null, @"Value ""{0}"" must be array.", name));

			var array = v2.AsBsonArray;
			if (all)
				array.AddRange(value.AsBsonArray);
			else
				array.Add(value);
		}
		static Expression PushExpression(Expression that, Expression field, BsonValue value)
		{
			BsonDocument d;
			BsonElement e;
			if (value.BsonType == BsonType.Document && (d = value.AsBsonDocument).ElementCount > 0 && (e = d.GetElement(0)).Name == "$each")
			{
				if (e.Value.BsonType != BsonType.Array)
					throw new ArgumentException("Push all/each value must be array.");

				var each = e.Value.AsBsonArray;

				BsonValue sort = null, slice = null;
				for (int i = 1; i < d.ElementCount; ++i)
				{
					e = d.GetElement(i);
					switch (e.Name)
					{
						case "$sort":
							sort = e.Value;
							break;
						case "$slice":
							slice = e.Value;
							break;
						default:
							throw new ArgumentException("$each term takes only $slice (and optionally $sort) as complements.");
					}
				}

				if (sort == null && slice == null)
					return Expression.Call(that, GetMethod("PushAll"), Data, field, Expression.Constant(each, typeof(BsonValue)));

				if (sort != null)
				{
					//! order

					if (sort.BsonType != BsonType.Document)
						throw new ArgumentException("$sort component of $push must be an object.");

					foreach (var d1 in each)
						if (d1.BsonType != BsonType.Document)
							throw new ArgumentException("$sort requires $each to be an array of objects.");

					if (slice == null)
						throw new ArgumentException("$push $each cannot have a $sort without a $slice.");

					// sort
					each = new BsonArray(QueryCompiler.Query(each.Cast<BsonDocument>(), null, new SortByDocument(sort.AsBsonDocument), 0, 0));
				}

				if (!slice.IsNumeric)
					throw new ArgumentException("$slice value must be a numeric integer.");

				int sliceVal = slice.ToInt32();
				if (sliceVal > 0)
					throw new ArgumentException("$slice value must be negative or zero.");

				return Expression.Call(that, GetMethod("PushAll"), Data, field, Expression.Constant(each.Slice(0, sliceVal), typeof(BsonValue)));
			}
			return Expression.Call(that, GetMethod("Push"), Data, field, Expression.Constant(value, typeof(BsonValue)));
		}
		UpdateCompiler Push(BsonDocument document, string name, BsonValue value)
		{

			Push(document, name, value, false);
			return this;
		}
		static Expression PushAllExpression(Expression that, Expression field, BsonValue value)
		{
			if (value.BsonType != BsonType.Array)
				throw new ArgumentException("Push all/each value must be array.");

			return Expression.Call(that, GetMethod("PushAll"), Data, field, Expression.Constant(value, typeof(BsonValue)));
		}
		UpdateCompiler PushAll(BsonDocument document, string name, BsonValue value)
		{
			Push(document, name, value, true);
			return this;
		}
		static Expression RenameExpression(Expression that, Expression field, BsonValue value)
		{
			return Expression.Call(that, GetMethod("Rename"), Data, field, Expression.Constant(value.AsString, typeof(string)));
		}
		UpdateCompiler Rename(BsonDocument document, string name, string newName)
		{
			var r1 = document.ResolvePath(name, true); //_131028_234439 Weird, we can rename in arrays but follow Mongo that cannot.
			if (r1 != null)
			{
				BsonValue value;
				if (r1.Document.TryGetValue(r1.Key, out value))
				{
					var r2 = document.EnsurePath(newName);
					r1.Document.Remove(r1.Key);
					r2.Document[r2.Key] = value;
				}
			}
			return this;
		}
		static Expression SetExpression(Expression that, Expression field, BsonValue value)
		{
			return Expression.Call(that, GetMethod("Set"), Data, field, Expression.Constant(value, typeof(BsonValue)));
		}
		UpdateCompiler Set(BsonDocument document, string name, BsonValue value)
		{
			var r = document.EnsurePath(name);
			if (r.Document != null)
			{
				r.Document[r.Key] = value;
			}
			else if (!r.Array.InsertOutOfRange(r.Index, () => value))
			{
				r.Array[r.Index] = value;
			}
			return this;
		}
		static Expression UnsetExpression(Expression that, Expression field)
		{
			return Expression.Call(that, GetMethod("Unset"), Data, field);
		}
		UpdateCompiler Unset(BsonDocument document, string name)
		{
			var r = document.ResolvePath(name);
			if (r != null)
			{
				if (r.Document != null)
					r.Document.Remove(r.Key);
				else
					r.Array[r.Index] = BsonNull.Value;
			}
			return this;
		}
		#endregion
		readonly static ParameterExpression Data = Expression.Parameter(typeof(BsonDocument), "data");
		static MethodInfo GetMethod(string name)
		{
			return typeof(UpdateCompiler).GetMethod(name, BindingFlags.NonPublic | BindingFlags.Instance);
		}
		static Expression OperatorExpression(Expression that, string operatorName, Expression field, BsonValue value, bool insert)
		{
			switch (operatorName)
			{
				case "$addToSet": return AddToSetExpression(that, field, value);
				case "$bit": return BitwiseExpression(that, field, value);
				case "$inc": return IncExpression(that, field, value);
				case "$pop": return PopExpression(that, field, value);
				case "$pull": return PullExpression(that, field, value);
				case "$pullAll": return PullAllExpression(that, field, value);
				case "$push": return PushExpression(that, field, value);
				case "$pushAll": return PushAllExpression(that, field, value);
				case "$rename": return RenameExpression(that, field, value);
				case "$set": return SetExpression(that, field, value);
				case "$setOnInsert": return insert ? SetExpression(that, field, value) : that;
				case "$unset": return UnsetExpression(that, field);
				default:
					throw new NotImplementedException("Not implemented operator " + operatorName);
			}
		}
		static Expression UpdateFromQueryExpression(Expression that, object query)
		{
			if (query == null)
				return that;

			foreach (var element in Actor.ObjectToQueryDocument(query))
			{
				if (element.Name[0] == '$')
					continue;

				var selector = element.Value;
				if (selector.IsBsonRegularExpression)
					continue;

				var document = selector as BsonDocument;
				if (document != null && document.ElementCount > 0)
				{
					var name = document.GetElement(0).Name;
					if (name[0] == '$' && name != "$ref")
						continue;
				}

				that = UpdateCompiler.SetExpression(that, Expression.Constant(element.Name, typeof(string)), selector);
			}

			return that;
		}
		static void ValidateFieldName(string fieldName, List<string> names)
		{
			foreach (var name in names)
			{
				if (name.StartsWith(fieldName, StringComparison.Ordinal) && (name.Length == fieldName.Length || name[fieldName.Length] == '.') ||
					fieldName.StartsWith(name, StringComparison.Ordinal) && (name.Length == fieldName.Length || fieldName[name.Length] == '.'))
					throw new InvalidOperationException(string.Format(null, @"Conflicting fields ""{0}"" and ""{1}"".", name, fieldName));
			}
			names.Add(fieldName);
		}
		static void ThrowMixedOperatorsAndNames()
		{
			throw new InvalidOperationException("Update cannot mix operators and fields.");
		}
		// public for tests
		public static Expression GetExpression(object update, object query, bool insert)
		{
			var compiler = new UpdateCompiler();
			Expression expression = Expression.Constant(compiler, typeof(UpdateCompiler));

			if (update == null)
				return expression;

			if (insert)
				expression = UpdateFromQueryExpression(expression, query);

			update = PSObject.AsPSObject(update).BaseObject;
			BsonDocument document;
			var builder = update as UpdateBuilder;
			if (builder != null)
				document = builder.ToBsonDocument();
			else if ((document = update as BsonDocument) == null)
				throw new ArgumentException(string.Format(null, "Invalid update object type {0}.", update.GetType()));

			bool isName = false;
			bool isOper = false;
			var names = new List<string>();
			foreach (var element in document)
			{
				var name = element.Name;
				if (name[0] == '$')
				{
					if (isName) ThrowMixedOperatorsAndNames();
					isOper = true;

					foreach (var fieldElement in element.Value.AsBsonDocument)
					{
						var fieldName = fieldElement.Name;
						ValidateFieldName(fieldName, names);
						expression = OperatorExpression(expression, name, Expression.Constant(fieldName, typeof(string)), fieldElement.Value, insert);
					}
				}
				else //_131103_204607
				{
					if (isOper) ThrowMixedOperatorsAndNames();
					isName = true;

					ValidateFieldName(name, names);
					expression = SetExpression(expression, Expression.Constant(name, typeof(string)), element.Value);
				}
			}

			return expression;
		}
		internal static Func<BsonDocument, UpdateCompiler> GetFunction(object update, object query, bool insert)
		{
			return Expression.Lambda<Func<BsonDocument, UpdateCompiler>>(GetExpression(update, query, insert), Data).Compile();
		}
		// public for tests
		public static Func<BsonDocument, UpdateCompiler> GetFunction(Expression expression)
		{
			return Expression.Lambda<Func<BsonDocument, UpdateCompiler>>(expression, Data).Compile();
		}
	}
}
