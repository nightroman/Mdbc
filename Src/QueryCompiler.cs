
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
		static bool Matches(BsonDocument document, string name, Regex regex)
		{
			if (regex == null)
				return false;

			foreach (var data in document.GetNestedValues(name))
				if (data.BsonType == BsonType.String && regex.IsMatch(data.AsString))
					return true;

			return false;
		}
		// If the field is missing or the size is empty then false.
		static bool All(BsonDocument document, string name, BsonArray value)
		{
			if (value.Count == 0)
				return false;

			foreach (var data in document.GetNestedValues(name))
			{
				if (data.BsonType != BsonType.Array)
				{
					foreach (var it in value)
						if (data.CompareTo(it) != 0)
							goto next;
					return true;
				}

				foreach (var it in value)
					if (data.AsBsonArray.FirstOrDefault(x => it.CompareTo(x) == 0) == null)
						goto next;
				return true;

			next: ;
			}

			return false;
		}
		static bool In(BsonDocument document, string name, BsonArray value)
		{
			foreach (var data in document.GetNestedValues(name))
			{
				if (data.BsonType != BsonType.Array)
					if (value.FirstOrDefault(x => data.CompareTo(x) == 0) != null)
						return true;
					else
						continue;

				foreach (var it in data.AsBsonArray)
					if (value.FirstOrDefault(x => it.CompareTo(x) == 0) != null)
						return true;
			}

			return false;
		}
		// If missing or not a number then false else numbers are converted to long.
		static bool Mod(BsonDocument document, string name, long modulus, long value)
		{
			foreach (var data in document.GetNestedValues(name))
			{
				switch (data.BsonType)
				{
					case BsonType.Int64:
						if (data.AsInt64 % modulus == value)
							return true;
						break;
					case BsonType.Int32:
						if ((long)data.AsInt32 % modulus == value)
							return true;
						break;
					case BsonType.Double:
						if ((long)data.AsDouble % modulus == value)
							return true;
						break;
				}
			}

			return false;
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
		static bool Type(BsonDocument document, string name, BsonType type)
		{
			foreach (var data in document.GetNestedValues(name))
				if (data.BsonType == type)
					return true;

			return false;
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
		static Expression FieldOperatorExpression(string fieldName, string operatorName, BsonValue args)
		{
			var field = Expression.Constant(fieldName, typeof(string));
			switch (operatorName)
			{
				case "$exists":
					var existsValue = LanguagePrimitives.IsTrue(Actor.ToObject(args));
					return Expression.Equal(
						Expression.Call(Data, typeof(BsonDocument).GetMethod("Contains"), field),
						Expression.Constant(existsValue, typeof(bool)));
				case "$gt":
					return Expression.Call(GetMethod("GT"), Data, field, Expression.Constant(args, typeof(BsonValue)));
				case "$gte":
					return Expression.Call(GetMethod("GTE"), Data, field, Expression.Constant(args, typeof(BsonValue)));
				case "$lt":
					return Expression.Call(GetMethod("LT"), Data, field, Expression.Constant(args, typeof(BsonValue)));
				case "$lte":
					return Expression.Call(GetMethod("LTE"), Data, field, Expression.Constant(args, typeof(BsonValue)));
				case "$all":
					return Expression.Call(GetMethod("All"), Data, field, Expression.Constant(args.AsBsonArray, typeof(BsonArray)));
				case "$in":
					return Expression.Call(GetMethod("In"), Data, field, Expression.Constant(args.AsBsonArray, typeof(BsonArray)));
				case "$nin":
					return Expression.Not(
						Expression.Call(GetMethod("In"), Data, field, Expression.Constant(args.AsBsonArray, typeof(BsonArray))));
				case "$mod":
					var mod = (BsonArray)args;
					long mod0 = (long)LanguagePrimitives.ConvertTo(Actor.ToObject(mod[0]), typeof(long), null);
					long mod1 = (long)LanguagePrimitives.ConvertTo(Actor.ToObject(mod[1]), typeof(long), null);
					return Expression.Call(GetMethod("Mod"), Data, field,
						Expression.Constant(mod0, typeof(long)), Expression.Constant(mod1, typeof(long)));
				case "$ne":
					return Expression.Call(GetMethod("NE"), Data, field, Expression.Constant(args, typeof(BsonValue)));
				case "$not":
					if (args.BsonType == BsonType.Document)
					{
						var not = args.AsBsonDocument.GetElement(0);
						return Expression.Not(FieldOperatorExpression(fieldName, not.Name, not.Value));
					}
					else
					{
						return Expression.Not(FieldValueExpression(fieldName, args));
					}
				case "$regex":
					var regex = args.BsonType == BsonType.RegularExpression ? args.AsRegex : null;
					return Expression.Call(GetMethod("Matches"), Data, field, Expression.Constant(regex, typeof(Regex)));
				case "$size":
					return Expression.Call(GetMethod("Size"), Data, field, Expression.Constant(args.ToDoubleOrZero(), typeof(double)));
				case "$type":
					return Expression.Call(GetMethod("Type"), Data, field, Expression.Constant((BsonType)args.ToInt32(), typeof(BsonType)));
				case "$elemMatch":
					var func = GetFunction(GetExpression(args.AsBsonDocument));
					return Expression.Call(
						GetMethod("ElemMatch"), Data, field, Expression.Constant(func, typeof(Func<BsonDocument, bool>)));
				default:
					throw new NotImplementedException("Not implemented operator " + operatorName);
			}
		}
		static Expression FieldValueExpression(string fieldName, BsonValue value)
		{
			var field = Expression.Constant(fieldName, typeof(string));
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
							switch (operatorName)
							{
								case "$and":
									r = Expression.And(r, GetExpression((BsonDocument)a[i]));
									break;
								default:
									r = Expression.Or(r, GetExpression((BsonDocument)a[i]));
									break;
							}

						if (operatorName == "$nor")
							r = Expression.Not(r);

						return r;
					}
				default:
					throw new NotImplementedException("Not implemented operator " + operatorName);
			}
		}
		static Expression FieldExpression(string fieldName, BsonValue selector)
		{
			var document = selector as BsonDocument;
			if (document != null && document.ElementCount > 0)
			{
				var element = document.GetElement(0);
				var operatorName = element.Name;
				if (operatorName[0] == '$' && operatorName != "$ref")
				{
					// combined And on a field: { field: { $ne: 1, $exists: true } }
					var r = FieldOperatorExpression(fieldName, operatorName, element.Value);
					for (int i = 1; i < document.ElementCount; ++i)
					{
						element = document.GetElement(i);
						r = Expression.And(r, FieldOperatorExpression(fieldName, element.Name, element.Value));
					}
					return r;
				}
			}

			return FieldValueExpression(fieldName, selector);
		}
		static Expression ElementExpression(BsonElement element)
		{
			if (element.Name[0] == '$')
				return OperatorExpression(element.Name, element.Value);
			else
				return FieldExpression(element.Name, element.Value);
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
		//TODO is compiler compiled? if not then how?
		internal static IEnumerable<BsonDocument> Query(IEnumerable<BsonDocument> documents, IMongoQuery query, IMongoSortBy sortBy, int first, int skip)
		{
			var queryableData = documents.AsQueryable<BsonDocument>();
			var predicateBody = GetExpression((BsonDocument)query);

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
