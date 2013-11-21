
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
using System.Text.RegularExpressions;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.Builders;

namespace Mdbc
{
	public static class QueryCompiler
	{
		#region Operators
		static Expression ExistsExpression(Expression field, BsonValue args)
		{
			return Expression.Equal(
				Expression.Call(Data, typeof(BsonDocument).GetMethod("Contains"), field),
				Expression.Constant(LanguagePrimitives.IsTrue(Actor.ToObject(args)), typeof(bool)));
		}
		static Expression NotExpression(Expression field, BsonValue args)
		{
			switch (args.BsonType)
			{
				case BsonType.Document:
					return Expression.Not(FieldExpression(field, args.AsBsonDocument));
				case BsonType.RegularExpression:
					return Expression.Not(MatchesExpression(field, args));
				default:
					throw new ArgumentException("Invalid form of $not.");
			}
		}
		static bool EQ(BsonDocument document, string name, BsonValue value)
		{
			bool ok = false;
			foreach (var data in document.GetNestedValues(name))
			{
				ok = true;
				if (data.CompareTo(value) == 0)
					return true;
			}
			return ok ? false : value.BsonType == BsonType.Null;
		}
		static Expression GTExpression(Expression field, BsonValue args)
		{
			return Expression.Call(GetMethod("GT"), Data, field, Expression.Constant(args, typeof(BsonValue)));
		}
		static bool GT(BsonDocument document, string name, BsonValue value)
		{
			bool ok = false;
			foreach (var data in document.GetNestedValues(name))
			{
				ok = true;
				if (data.CompareTo(value) > 0)
					return true;
			}

			return ok ? false : value.BsonType == BsonType.Null;
		}
		static Expression GTEExpression(Expression field, BsonValue args)
		{
			return Expression.Call(GetMethod("GTE"), Data, field, Expression.Constant(args, typeof(BsonValue)));
		}
		static bool GTE(BsonDocument document, string name, BsonValue value)
		{
			bool ok = false;
			foreach (var data in document.GetNestedValues(name))
			{
				ok = true;
				if (data.CompareTo(value) >= 0)
					return true;
			}
			return ok ? false : value.BsonType == BsonType.Null;
		}
		static Expression NEExpression(Expression field, BsonValue args)
		{
			return Expression.Call(GetMethod("NE"), Data, field, Expression.Constant(args, typeof(BsonValue)));
		}
		static bool NE(BsonDocument document, string name, BsonValue value)
		{
			bool ok = false;
			foreach (var data in document.GetNestedValues(name))
			{
				ok = true;
				if (data.CompareTo(value) != 0)
					return true;
			}
			return ok ? false : value.BsonType != BsonType.Null;
		}
		static Expression LTExpression(Expression field, BsonValue args)
		{
			return Expression.Call(GetMethod("LT"), Data, field, Expression.Constant(args, typeof(BsonValue)));
		}
		static bool LT(BsonDocument document, string name, BsonValue value)
		{
			bool ok = false;
			foreach (var data in document.GetNestedValues(name))
			{
				ok = true;
				if (data.CompareTo(value) < 0)
					return true;
			}
			return ok ? false : value.BsonType == BsonType.Null;
		}
		static Expression LTEExpression(Expression field, BsonValue args)
		{
			return Expression.Call(GetMethod("LTE"), Data, field, Expression.Constant(args, typeof(BsonValue)));
		}
		static bool LTE(BsonDocument document, string name, BsonValue value)
		{
			bool ok = false;
			foreach (var data in document.GetNestedValues(name))
			{
				ok = true;
				if (data.CompareTo(value) <= 0)
					return true;
			}
			return ok ? false : value.BsonType == BsonType.Null;
		}
		static Expression MatchesExpression(Expression field, BsonValue args)
		{
			var regex = args.BsonType == BsonType.RegularExpression ? args.AsRegex : null;
			return Expression.Call(GetMethod("Matches"), Data, field, Expression.Constant(regex, typeof(Regex)));
		}
		static bool Matches(BsonDocument document, string name, Regex regex)
		{
			if (regex == null)
				return false;

			foreach (var data in document.GetNestedValues(name))
				if (data.BsonType == BsonType.String && regex.IsMatch(data.AsString))
					return true;

			return false;
		}
		static Expression AllExpression(Expression field, BsonValue args)
		{
			if (args.BsonType != BsonType.Array)
				throw new ArgumentException("$all argument must be array.");

			var all = new List<object>();
			foreach (var one in args.AsBsonArray)
			{
				//_131116_140311 As Mongo, just check the first element, ignore others
				BsonDocument d; BsonElement e;
				if (one.BsonType == BsonType.Document && (d = one.AsBsonDocument).ElementCount > 0 && (e = d.GetElement(0)).Name == "$elemMatch")
				{
					if (e.Value.BsonType != BsonType.Document)
						throw new ArgumentException("$all $elemMatch argument must be document.");

					all.Add(GetFunction(GetExpression(e.Value.AsBsonDocument)));
				}
				else
				{
					all.Add(one);
				}
			}
			return Expression.Call(GetMethod("All"), Data, field, Expression.Constant(all, typeof(List<object>)));
		}
		// If the field is missing or the size is empty then false.
		static bool All(BsonDocument document, string name, List<object> all)
		{
			if (all.Count == 0)
				return false;

			foreach (var data in document.GetNestedValues(name))
			{
				if (data.BsonType != BsonType.Array)
				{
					foreach (var one in all)
						if (!data.EqualsOrElemMatches(one))
							goto next;
					return true;
				}

				foreach (var one in all)
					if (data.AsBsonArray.FirstOrDefault(x => x.EqualsOrElemMatches(one)) == null)
						goto next;
				return true;

			next: ;
			}

			return false;
		}
		static Expression InExpression(Expression field, BsonValue args)
		{
			if (args.BsonType != BsonType.Array)
				throw new ArgumentException("$in/$nin argument must be array.");

			return Expression.Call(GetMethod("In"), Data, field, Expression.Constant(args.AsBsonArray, typeof(BsonArray)));
		}
		static bool In(BsonDocument document, string name, BsonArray value)
		{
			foreach (var data in document.GetNestedValues(name))
			{
				if (data.BsonType != BsonType.Array)
					if (value.FirstOrDefault(x => data.EqualsOrMatches(x)) != null)
						return true;
					else
						continue;

				foreach (var it in data.AsBsonArray)
					if (value.FirstOrDefault(x => it.EqualsOrMatches(x)) != null)
						return true;
			}

			return false;
		}
		static Expression ModExpression(Expression field, BsonValue args)
		{
			if (args.BsonType != BsonType.Array)
				throw new ArgumentException("$mod argument must be array.");

			var mod = args.AsBsonArray;

			long mod0 = mod.Count > 0 ? (long)mod[0].ToDoubleOrZero() : 0;
			if (mod0 == 0)
				throw new ArgumentException("$mod divisor cannot be 0.");

			long mod1 = mod.Count > 1 ? (long)mod[1].ToDoubleOrZero() : 0;

			return Expression.Call(GetMethod("Mod"), Data, field, Expression.Constant(mod0, typeof(long)), Expression.Constant(mod1, typeof(long)));
		}
		// If missing or not a number then false else numbers are converted to long.
		static bool Mod(BsonDocument document, string name, long divisor, long value)
		{
			foreach (var data in document.GetNestedValues(name))
			{
				switch (data.BsonType)
				{
					case BsonType.Int64:
						if (data.AsInt64 % divisor == value)
							return true;
						break;
					case BsonType.Int32:
						if ((long)data.AsInt32 % divisor == value)
							return true;
						break;
					case BsonType.Double:
						if ((long)data.AsDouble % divisor == value)
							return true;
						break;
				}
			}

			return false;
		}
		static Expression SizeExpression(Expression field, BsonValue args)
		{
			return Expression.Call(GetMethod("Size"), Data, field, Expression.Constant(args.ToDoubleOrZero(), typeof(double)));
		}
		// If missing or not a number then false.
		// If value is not a number then size 0 is used instead.
		// Why double: Mongo allows long and doubles and compares doubles with sizes literally.
		static bool Size(BsonDocument document, string name, double size)
		{
			foreach (var data in document.GetNestedValues(name))
				if (data.BsonType == BsonType.Array && data.AsBsonArray.Count == size)
					return true;

			return false;
		}
		static Expression TypeExpression(Expression field, BsonValue args)
		{
			if (!args.IsNumeric)
				throw new ArgumentException("$type argument must be number.");

			return Expression.Call(GetMethod("Type"), Data, field, Expression.Constant((BsonType)args.ToInt32(), typeof(BsonType)));
		}
		static bool Type(BsonDocument document, string name, BsonType type)
		{
			foreach (var data in document.GetNestedValues(name))
				if (data.BsonType == type)
					return true;

			return false;
		}
		static Expression ElemMatchExpression(Expression field, BsonValue args)
		{
			if (args.BsonType != BsonType.Document)
				throw new ArgumentException("$elemMatch argument must be document.");

			return Expression.Call(GetMethod("ElemMatch"), Data, field, Expression.Constant(GetFunction(GetExpression(args.AsBsonDocument)), typeof(Func<BsonDocument, bool>)));
		}
		static bool ElemMatch(BsonDocument document, string name, Func<BsonDocument, bool> predicate)
		{
			foreach (var data in document.GetNestedValues(name))
			{
				if (data.BsonType != BsonType.Array)
					continue;

				foreach (var doc in data.AsBsonArray)
					if (doc.BsonType == BsonType.Document && predicate(doc.AsBsonDocument))
						return true;
			}

			return false;
		}
		#endregion
		readonly static ParameterExpression Data = Expression.Parameter(typeof(BsonDocument), "data");
		static MethodInfo GetMethod(string name)
		{
			return typeof(QueryCompiler).GetMethod(name, BindingFlags.NonPublic | BindingFlags.Static);
		}
		static Expression FieldOperatorExpression(Expression field, string operatorName, BsonValue args)
		{
			switch (operatorName)
			{
				case "$all": return AllExpression(field, args);
				case "$elemMatch": return ElemMatchExpression(field, args);
				case "$exists": return ExistsExpression(field, args);
				case "$gt": return GTExpression(field, args);
				case "$gte": return GTEExpression(field, args);
				case "$in": return InExpression(field, args);
				case "$lt": return LTExpression(field, args);
				case "$lte": return LTEExpression(field, args);
				case "$mod": return ModExpression(field, args);
				case "$ne": return NEExpression(field, args);
				case "$nin": return Expression.Not(InExpression(field, args));
				case "$not": return NotExpression(field, args);
				case "$regex": return MatchesExpression(field, args);
				case "$size": return SizeExpression(field, args);
				case "$type": return TypeExpression(field, args);
				default:
					throw new NotImplementedException("Not implemented operator " + operatorName);
			}
		}
		static Expression FieldValueExpression(Expression field, BsonValue value)
		{
			if (value.IsBsonRegularExpression)
				return Expression.Call(GetMethod("Matches"), Data, field, Expression.Constant(value.AsRegex, typeof(Regex)));
			else
				return Expression.Call(GetMethod("EQ"), Data, field, Expression.Constant(value, typeof(BsonValue)));
		}
		static Expression OperatorExpression(string operatorName, BsonValue args)
		{
			switch (operatorName)
			{
				case "$and":
				case "$or":
				case "$nor":
					{
						var a = (BsonArray)args;
						var r = GetExpression((BsonDocument)a[0]);

						for (int i = 1; i < a.Count; ++i)
						{
							var e = GetExpression((BsonDocument)a[i]);
							r = operatorName == "$and" ? Expression.And(r, e) : Expression.Or(r, e);
						}

						if (operatorName == "$nor")
							r = Expression.Not(r);

						return r;
					}
				default:
					throw new NotImplementedException("Not implemented operator " + operatorName);
			}
		}
		static Expression FieldExpression(Expression field, BsonValue selector)
		{
			var document = selector as BsonDocument;
			if (document != null && document.ElementCount > 0)
			{
				var element = document.GetElement(0);
				var operatorName = element.Name;
				if (operatorName[0] == '$' && operatorName != "$ref")
				{
					// combined And on a field: { field: { $ne: 1, $exists: true } }
					var r = FieldOperatorExpression(field, operatorName, element.Value);
					for (int i = 1; i < document.ElementCount; ++i)
					{
						element = document.GetElement(i);
						r = Expression.And(r, FieldOperatorExpression(field, element.Name, element.Value));
					}
					return r;
				}
			}

			return FieldValueExpression(field, selector);
		}
		static Expression ElementExpression(BsonElement element)
		{
			if (element.Name[0] == '$')
				return OperatorExpression(element.Name, element.Value);
			else
				return FieldExpression(Expression.Constant(element.Name, typeof(string)), element.Value);
		}
		static Expression DocumentExpression(BsonDocument query)
		{
			var r = ElementExpression(query.GetElement(0));
			for (int i = 1; i < query.ElementCount; ++i)
				r = Expression.And(r, ElementExpression(query.GetElement(i)));
			return r;
		}
		// public for tests
		public static Expression GetExpression(object query)
		{
			if (query == null)
				return Expression.Constant(true, typeof(bool));

			var document = Actor.ObjectToQueryDocument(query);
			switch (document.ElementCount)
			{
				case 1:
					return ElementExpression(document.GetElement(0));
				case 0:
					return Expression.Constant(true, typeof(bool));
				default:
					return DocumentExpression(document);
			}
		}
		internal static Func<BsonDocument, bool> GetFunction(object query)
		{
			return Expression.Lambda<Func<BsonDocument, bool>>(GetExpression(query), Data).Compile();
		}
		// public for tests
		public static Func<BsonDocument, bool> GetFunction(Expression expression)
		{
			return Expression.Lambda<Func<BsonDocument, bool>>(expression, Data).Compile();
		}
		static BsonDocument SortByToBsonDocument(IMongoSortBy sortBy)
		{
			return sortBy as BsonDocument ?? ((SortByBuilder)sortBy).ToBsonDocument();
		}
		static IEnumerable<BsonDocument> OptimisedDocuments(IDictionary<BsonValue, BsonDocument> dictionary, BsonValue idSelector)
		{
			BsonDocument document;

			switch (idSelector.BsonType)
			{
				case BsonType.RegularExpression:
					var regex = idSelector.AsRegex;
					return dictionary.Keys.Where(x => x.BsonType == BsonType.String && regex.IsMatch(x.AsString)).Select(x => dictionary[x]);
				case BsonType.Document:
					document = idSelector.AsBsonDocument;
					if (document.ElementCount > 0)
					{
						var name = document.GetElement(0).Name;
						if (name[0] == '$' && name != "$ref")
							return dictionary.Values;
					}
					break;
			}

			if (dictionary.TryGetValue(idSelector, out document))
				return new BsonDocument[] { document };

			return null;
		}
		internal static IEnumerable<BsonDocument> Query(IEnumerable<BsonDocument> documents, IDictionary<BsonValue, BsonDocument> dictionary, IMongoQuery query, IMongoSortBy sortBy, int skip, int first)
		{
			var queryDocument = (BsonDocument)query;

			BsonValue idSelector;
			if (dictionary != null && queryDocument != null && queryDocument.TryGetValue(MyValue.Id, out idSelector))
			{
				documents = OptimisedDocuments(dictionary, idSelector);
				if (documents == null)
					return new BsonDocument[] { };
			}

			var queryableData = documents.AsQueryable<BsonDocument>();
			var predicateBody = GetExpression(queryDocument);

			var expression = Expression.Call(
				typeof(Queryable),
				"Where",
				new Type[] { queryableData.ElementType },
				queryableData.Expression,
				Expression.Lambda<Func<BsonDocument, bool>>(predicateBody, Data));

			var miGetValue = typeof(BsonDocument).GetMethod("GetValue", new Type[] { typeof(string) });

			if (sortBy != null)
			{
				var sortDocument = SortByToBsonDocument(sortBy);
				for (int i = 0; i < sortDocument.ElementCount; ++i)
				{
					var element = sortDocument.GetElement(i);

					var selector = Expression.Call(Data, miGetValue, Expression.Constant(element.Name, typeof(string)));

					string sortMethodName;
					if (i == 0)
						sortMethodName = element.Value.AsInt32 > 0 ? "OrderBy" : "OrderByDescending";
					else
						sortMethodName = element.Value.AsInt32 > 0 ? "ThenBy" : "ThenByDescending";

					expression = Expression.Call(
						typeof(Queryable),
						sortMethodName,
						new Type[] { queryableData.ElementType, typeof(BsonValue) },
						expression,
						Expression.Lambda<Func<BsonDocument, BsonValue>>(selector, Data));
				}
			}

			if (skip > 0)
			{
				expression = Expression.Call(
					typeof(Queryable),
					"Skip",
					new Type[] { queryableData.ElementType },
					expression,
					Expression.Constant(skip, typeof(int)));
			}

			if (first > 0)
			{
				expression = Expression.Call(
					typeof(Queryable),
					"Take",
					new Type[] { queryableData.ElementType },
					expression,
					Expression.Constant(first, typeof(int)));
			}

			return queryableData.Provider.CreateQuery<BsonDocument>(expression);
		}
	}
}
