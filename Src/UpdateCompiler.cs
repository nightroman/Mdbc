
// Copyright (c) 2011-2016 Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Reflection;
using MongoDB.Bson;
using MongoDB.Driver;

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

			value.ValidateNames();

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
				case "xor":
					return Expression.Call(that, GetMethod("BitwiseXor"), Data, field, Expression.Constant(v, typeof(BsonValue)));
				default:
					throw new ArgumentException(@"Bitwise value element name must be ""and"", ""or"", or ""xor"".");
			}
		}
		static void Bitwise(BsonDocument document, string name, BsonValue value, int type)
		{
			var r = document.EnsurePath(name);

			BsonValue old;
			if (r.Array != null)
			{
				r.Array.InsertOutOfRange(r.Index, () => 0);

				old = r.Array[r.Index];
				if (old.BsonType != BsonType.Int32 && old.BsonType != BsonType.Int64)
					throw new MongoException(string.Format(null, @"Item ""{0}"" must be Int32 or Int64.", name));

				switch (type)
				{
					case 0: r.Array[r.Index] = MyValue.BitwiseAnd(old, value); break;
					case 1: r.Array[r.Index] = MyValue.BitwiseOr(old, value); break;
					default: r.Array[r.Index] = MyValue.BitwiseXor(old, value); break;
				}
			}
			else if (r.Document.TryGetValue(r.Key, out old))
			{
				if (old.BsonType != BsonType.Int32 && old.BsonType != BsonType.Int64)
					throw new MongoException(string.Format(null, @"Field ""{0}"" must be Int32 or Int64.", name));

				switch (type)
				{
					case 0: r.Document[r.Key] = MyValue.BitwiseAnd(old, value); break;
					case 1: r.Document[r.Key] = MyValue.BitwiseOr(old, value); break;
					default: r.Document[r.Key] = MyValue.BitwiseXor(old, value); break;
				}
			}
		}
		UpdateCompiler BitwiseAnd(BsonDocument document, string name, BsonValue value)
		{
			Bitwise(document, name, value, 0);
			return this;
		}
		UpdateCompiler BitwiseOr(BsonDocument document, string name, BsonValue value)
		{
			Bitwise(document, name, value, 1);
			return this;
		}
		UpdateCompiler BitwiseXor(BsonDocument document, string name, BsonValue value)
		{
			Bitwise(document, name, value, 2);
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
		static Expression MulExpression(Expression that, Expression field, BsonValue value)
		{
			if (value == null || !value.IsNumeric)
				throw new ArgumentException("Multiply value must be numeric.");

			return Expression.Call(that, GetMethod("Mul"), Data, field, Expression.Constant(value, typeof(BsonValue)));
		}
		UpdateCompiler Mul(BsonDocument document, string name, BsonValue value)
		{
			var r = document.EnsurePath(name);
			BsonValue old;
			if (r.Document != null)
			{
				if (r.Document.TryGetValue(r.Key, out old))
				{
					if (!old.IsNumeric)
						throw new MongoException(string.Format(null, @"Field ""{0}"" must be numeric.", name));
				}
				else
				{
					old = 0;
				}

				r.Document[r.Key] = MyValue.Mul(old, value);
			}
			else if (!r.Array.InsertOutOfRange(r.Index, () => MyValue.Mul(0, value)))
			{
				old = r.Array[r.Index];
				if (!old.IsNumeric)
					throw new MongoException(string.Format(null, @"Item ""{0}"" must be numeric.", name));

				r.Array[r.Index] = MyValue.Mul(old, value);
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
				return this; //_140322_064404

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
				return; //_140322_065637

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
				//_131130_103226 Created in Update.Pull(query)
				var wrapper = value as BsonDocumentWrapper;
				if (wrapper != null)
					value = (BsonValue)wrapper.WrappedObject;

				var predicate = QueryCompiler.GetFunction(value.AsBsonDocument);
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
		static void Push(BsonDocument document, string name, BsonValue value, bool all, int position)
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
			{
				if (position < 0 || position >= array.Count)
				{
					array.AddRange(value.AsBsonArray);
				}
				else
				{
					var array2 = value.AsBsonArray;
					for (int i = array2.Count; --i >= 0; )
						array.Insert(position, array2[i]);
				}
			}
			else
			{
				//TODO is position actually used in this case?
				if (position < 0 || position >= array.Count)
					array.Add(value);
				else
					array.Insert(position, value);
			}
		}
		static Expression PushExpression(Expression that, Expression field, BsonValue value)
		{
			if (value.BsonType == BsonType.Document)
			{
				var d = value.AsBsonDocument;
				if (d.Contains("$each"))
					return PushEachExpression(that, field, d);
			}

			value.ValidateNames();

			return Expression.Call(that, GetMethod("Push"), Data, field, Expression.Constant(value, typeof(BsonValue)));
		}
		// Assume $each exists.
		// TODO AvoidExcessiveComplexity
		[System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Maintainability", "CA1502:AvoidExcessiveComplexity")]
		static Expression PushEachExpression(Expression that, Expression field, BsonDocument document)
		{
			int position = -1;
			BsonArray each = null;
			BsonValue sort = null, slice = null;
			foreach (var e in document.Elements)
			{
				//TODO
				switch (e.Name)
				{
					case "$each":
						if (e.Value.BsonType != BsonType.Array)
							throw new ArgumentException("Push all/each value must be array.");
						each = e.Value.AsBsonArray;
						break;
					case "$sort":
						sort = e.Value;
						break;
					case "$slice":
						if (!e.Value.IsNumeric)
							throw new ArgumentException("$slice must be a numeric value.");
						slice = e.Value;
						break;
					case "$position":
						if (!e.Value.IsNumeric)
							throw new ArgumentException("$position must be a numeric value.");
						position = e.Value.ToInt32();
						if (position < 0)
							throw new ArgumentException("$position must not be negative.");
						break;
					default:
						throw new ArgumentException(string.Format(null, "Unrecognized clause in $push: ({0}).", e.Name));
				}
			}

			if (sort != null)
			{
				switch (sort.BsonType)
				{
					case BsonType.Int32:
						switch (sort.AsInt32)
						{
							case 1:
								each = new BsonArray(each.OrderBy(x => x)); break; //TODO comparer?
							case -1:
								each = new BsonArray(each.OrderByDescending(x => x)); break; //TODO comparer?
							default:
								throw new ArgumentException("Numeric $sort value must be either 1 or -1.");
						}
						break;
					case BsonType.Document:
						//TODO not needed in Mongo v2.6
						foreach (var d1 in each)
							if (d1.BsonType != BsonType.Document)
								throw new ArgumentException("$sort requires $each to be an array of objects.");

						each = new BsonArray(QueryCompiler.Query(each.Cast<BsonDocument>(), null, null, new SortByDocument(sort.AsBsonDocument), 0, 0));
						break;
					default:
						throw new ArgumentException("$sort value must be 1, -1, or a document.");
				}
			}

			if (slice != null)
				each = each.Slice(0, slice.ToInt32());

			return Expression.Call(that, GetMethod("PushAll"), Data, field,
				Expression.Constant(each, typeof(BsonValue)), Expression.Constant(position, typeof(int)));
		}
		UpdateCompiler Push(BsonDocument document, string name, BsonValue value)
		{

			Push(document, name, value, false, -1);
			return this;
		}
		static Expression PushAllExpression(Expression that, Expression field, BsonValue value)
		{
			if (value.BsonType != BsonType.Array)
				throw new ArgumentException("Push all/each value must be array.");

			return Expression.Call(that, GetMethod("PushAll"), Data, field,
				Expression.Constant(value, typeof(BsonValue)), Expression.Constant(-1, typeof(int)));
		}
		UpdateCompiler PushAll(BsonDocument document, string name, BsonValue value, int position)
		{
			Push(document, name, value, true, position);
			return this;
		}
		static Expression RenameExpression(Expression that, Expression field, BsonValue value)
		{
			return Expression.Call(that, GetMethod("Rename"), Data, field, Expression.Constant(value.AsString, typeof(string)));
		}
		UpdateCompiler Rename(BsonDocument document, string name, string newName)
		{
			var r1 = document.ResolvePath(name, ResolvePathOptions.NoArray); //_131028_234439 Weird, we can rename in arrays but follow Mongo that cannot.
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
			value.ValidateNames();

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
		static Expression CurrentDateExpression(Expression that, Expression field)
		{
			return Expression.Call(that, GetMethod("CurrentDate"), Data, field);
		}
		UpdateCompiler CurrentDate(BsonDocument document, string name)
		{
			var value = new BsonDateTime(DateTime.Now);
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
		static Expression MaxExpression(Expression that, Expression field, BsonValue value)
		{
			return Expression.Call(that, GetMethod("Max"), Data, field, Expression.Constant(value, typeof(BsonValue)));
		}
		UpdateCompiler Max(BsonDocument document, string name, BsonValue value)
		{
			value.ValidateNames();

			var r = document.EnsurePath(name);
			if (r.Document != null)
			{
				BsonValue old;
				if (!r.Document.TryGetValue(r.Key, out old) || value.CompareTo(old) > 0)
					r.Document[r.Key] = value;
			}
			else if (!r.Array.InsertOutOfRange(r.Index, () => value))
			{
				if (value.CompareTo(r.Array[r.Index]) > 0)
					r.Array[r.Index] = value;
			}
			return this;
		}
		static Expression MinExpression(Expression that, Expression field, BsonValue value)
		{
			return Expression.Call(that, GetMethod("Min"), Data, field, Expression.Constant(value, typeof(BsonValue)));
		}
		UpdateCompiler Min(BsonDocument document, string name, BsonValue value)
		{
			value.ValidateNames();

			var r = document.EnsurePath(name);
			if (r.Document != null)
			{
				BsonValue old;
				if (!r.Document.TryGetValue(r.Key, out old) || value.CompareTo(old) < 0)
					r.Document[r.Key] = value;
			}
			else if (!r.Array.InsertOutOfRange(r.Index, () => value))
			{
				if (value.CompareTo(r.Array[r.Index]) < 0)
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
			//_140322_154514 negative index
			var r = document.ResolvePath(name, ResolvePathOptions.YesNegativeIndex);
			if (r == null)
				return this;

			if (r.Document != null)
				r.Document.Remove(r.Key);
			else
				r.Array[r.Index] = BsonNull.Value;

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
				case "$currentDate": return CurrentDateExpression(that, field);
				case "$inc": return IncExpression(that, field, value);
				case "$max": return MaxExpression(that, field, value);
				case "$min": return MinExpression(that, field, value);
				case "$mul": return MulExpression(that, field, value);
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
		static Expression UpdateFromQueryExpression(Expression that, IConvertibleToBsonDocument query)
		{
			if (query == null)
				return that;

			foreach (var element in query.ToBsonDocument())
			{
				// v2.6 fails
				if (element.Name[0] == '$')
					throw new ArgumentException(string.Format(null, "Unknown top level query operator: ({0}).", element.Name));

				var selector = element.Value;
				switch (selector.BsonType)
				{
					case BsonType.RegularExpression:
						continue;
					case BsonType.Document: //TODO _140223_223449
						var document = selector.AsBsonDocument;
						if (document.ElementCount > 0)
						{
							var name = document.GetElement(0).Name;
							if (name[0] == '$' && name != "$ref")
								continue;
						}
						break;
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
		public static Expression GetExpression(IConvertibleToBsonDocument update, IConvertibleToBsonDocument query, bool insert)
		{
			var compiler = new UpdateCompiler();
			Expression expression = Expression.Constant(compiler, typeof(UpdateCompiler));

			if (update == null)
				return expression;

			if (insert)
				expression = UpdateFromQueryExpression(expression, query);

			var document = update.ToBsonDocument();

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
		internal static Func<BsonDocument, UpdateCompiler> GetFunction(IConvertibleToBsonDocument update, IConvertibleToBsonDocument query, bool insert)
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
