
// Copyright (c) 2011-2016 Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections.Generic;
using System.Management.Automation;
using MongoDB.Bson;

namespace Mdbc
{
	//_131102_084424 Unwraps PSObject's like Get-Date.
	class PSObjectTypeMapper : ICustomBsonTypeMapper
	{
		public bool TryMapToBsonValue(object value, out BsonValue bsonValue)
		{
			var ps = value as PSObject;
			if (ps != null)
				return BsonTypeMapper.TryMapToBsonValue(ps.BaseObject, out bsonValue);
			bsonValue = null;
			return false;
		}
	}
	class IntLong
	{
		public int? Int;
		public long? Long;
		public IntLong(object value)
		{
			if (value is int)
				Int = (int)value;
			else if (value is long)
				Long = (long)value;
			else
				throw new InvalidCastException("Invalid type. Expected types: int, long.");
		}
	}
	class IntLongDouble
	{
		public int? Int;
		public long? Long;
		public double? Double;
		public IntLongDouble(object value)
		{
			if (value is int)
				Int = (int)value;
			else if (value is long)
				Long = (long)value;
			else if (value is double)
				Double = (double)value;
			else
				throw new InvalidCastException("Invalid type. Expected types: int, long, double.");
		}
	}
	class SetDollar : IDisposable
	{
		PSVariable Variable;
		object OldValue;
		public SetDollar(SessionState session, object value)
		{
			Variable = session.PSVariable.Get("_");
			if (Variable == null)
			{
				session.PSVariable.Set("_", value);
			}
			else
			{
				OldValue = Variable.Value;
				Variable.Value = value;
			}
		}
		public void Dispose()
		{
			if (Variable != null)
				Variable.Value = OldValue;
		}
	}
	class ParameterAs
	{
		internal readonly Type Type;
		public ParameterAs(PSObject value)
		{
			if (value == null)
			{
				Type = typeof(Dictionary);
				return;
			}

			var type = value.BaseObject as Type;
			if (type != null)
			{
				Type = (Type)LanguagePrimitives.ConvertTo(value, typeof(Type), null);
				return;
			}

			switch ((OutputType)LanguagePrimitives.ConvertTo(value, typeof(OutputType), null))
			{
				case OutputType.Default:
					Type = typeof(Dictionary);
					return;
				case OutputType.Lazy:
					Type = typeof(LazyDictionary);
					return;
				case OutputType.Raw:
					Type = typeof(RawDictionary);
					return;
				case OutputType.PS:
					Type = typeof(PSObject);
					return;
			}
		}
	}
	//! Forces CompareTo because GetHashCode is not consistens with CompareTo
	class BsonValueCompareToEqualityComparer : IEqualityComparer<BsonValue>
	{
		public int GetHashCode(BsonValue obj)
		{
			return 0;
		}
		public bool Equals(BsonValue x, BsonValue y)
		{
			return x == null ? y == null : x.CompareTo(y) == 0;
		}
	}
	static class MyValue
	{
		public const string Id = "_id";
		public static void ValidateNames(this BsonValue that)
		{
			switch (that.BsonType)
			{
				case BsonType.Document:
					that.AsBsonDocument.ValidateNames();
					break;
				case BsonType.Array:
					that.AsBsonArray.ValidateNames();
					break;
			}
		}
		public static bool EqualsOrMatches(this BsonValue value1, BsonValue value2)
		{
			if (value2.BsonType != BsonType.RegularExpression)
				return value1.CompareTo(value2) == 0;

			if (value1.BsonType != BsonType.String)
				return false;

			return value2.AsRegex.IsMatch(value1.AsString);
		}
		public static bool EqualsOrElemMatches(this BsonValue value1, object value2)
		{
			var v2 = value2 as BsonValue;
			if (v2 != null)
				return value1.EqualsOrMatches(v2);

			if (value1.BsonType != BsonType.Document)
				return false;

			return ((Func<BsonDocument, bool>)value2)(value1.AsBsonDocument);
		}
		public static double ToDoubleOrZero(this BsonValue value)
		{
			switch (value.BsonType)
			{
				case BsonType.Int32: return value.AsInt32;
				case BsonType.Int64: return value.AsInt64;
				case BsonType.Double: return value.AsDouble;
				default: return 0;
			}
		}
		public static BsonValue Add(BsonValue v1, BsonValue v2)
		{
			switch (v1.BsonType)
			{
				case BsonType.Int32:
					switch (v2.BsonType)
					{
						case BsonType.Int32:
							return new BsonInt32(v1.AsInt32 + v2.AsInt32);
						case BsonType.Int64:
							return new BsonInt64(v1.AsInt32 + v2.AsInt64);
						case BsonType.Double:
							return new BsonDouble(v1.AsInt32 + v2.AsDouble);
						default: break;
					}
					break;
				case BsonType.Int64:
					switch (v2.BsonType)
					{
						case BsonType.Int32:
							return new BsonInt64(v1.AsInt64 + v2.AsInt32);
						case BsonType.Int64:
							return new BsonInt64(v1.AsInt64 + v2.AsInt64);
						case BsonType.Double:
							return new BsonDouble(v1.AsInt64 + v2.AsDouble);
						default: break;
					}
					break;
				case BsonType.Double:
					switch (v2.BsonType)
					{
						case BsonType.Int32:
							return new BsonDouble(v1.AsDouble + v2.AsInt32);
						case BsonType.Int64:
							return new BsonDouble(v1.AsDouble + v2.AsInt64);
						case BsonType.Double:
							return new BsonDouble(v1.AsDouble + v2.AsDouble);
						default: break;
					}
					break;
				default:
					break;
			}
			throw new InvalidOperationException("Addition expects numeric values.");
		}
		public static BsonValue Mul(BsonValue v1, BsonValue v2)
		{
			switch (v1.BsonType)
			{
				case BsonType.Int32:
					switch (v2.BsonType)
					{
						case BsonType.Int32:
							return new BsonInt32(v1.AsInt32 * v2.AsInt32);
						case BsonType.Int64:
							return new BsonInt64(v1.AsInt32 * v2.AsInt64);
						case BsonType.Double:
							return new BsonDouble(v1.AsInt32 * v2.AsDouble);
						default: break;
					}
					break;
				case BsonType.Int64:
					switch (v2.BsonType)
					{
						case BsonType.Int32:
							return new BsonInt64(v1.AsInt64 * v2.AsInt32);
						case BsonType.Int64:
							return new BsonInt64(v1.AsInt64 * v2.AsInt64);
						case BsonType.Double:
							return new BsonDouble(v1.AsInt64 * v2.AsDouble);
						default: break;
					}
					break;
				case BsonType.Double:
					switch (v2.BsonType)
					{
						case BsonType.Int32:
							return new BsonDouble(v1.AsDouble * v2.AsInt32);
						case BsonType.Int64:
							return new BsonDouble(v1.AsDouble * v2.AsInt64);
						case BsonType.Double:
							return new BsonDouble(v1.AsDouble * v2.AsDouble);
						default: break;
					}
					break;
				default:
					break;
			}
			throw new InvalidOperationException("Multiplication expects numeric values.");
		}
		public static BsonValue BitwiseAnd(BsonValue v1, BsonValue v2)
		{
			switch (v1.BsonType)
			{
				case BsonType.Int32:
					switch (v2.BsonType)
					{
						case BsonType.Int32:
							return new BsonInt32(v1.AsInt32 & v2.AsInt32);
						case BsonType.Int64:
							return new BsonInt64(v1.AsInt32 & v2.AsInt64);
						default: break;
					}
					break;
				case BsonType.Int64:
					switch (v2.BsonType)
					{
						case BsonType.Int32:
							return new BsonInt64(v1.AsInt64 & v2.AsInt32);
						case BsonType.Int64:
							return new BsonInt64(v1.AsInt64 & v2.AsInt64);
						default: break;
					}
					break;
				default:
					break;
			}
			throw new InvalidOperationException("Bitwise AND expects Int32 or Int64 values.");
		}
		public static BsonValue BitwiseOr(BsonValue v1, BsonValue v2)
		{
			switch (v1.BsonType)
			{
				case BsonType.Int32:
					switch (v2.BsonType)
					{
						case BsonType.Int32:
							return new BsonInt32(v1.AsInt32 | v2.AsInt32);
						case BsonType.Int64:
							return new BsonInt64((uint)v1.AsInt32 | v2.AsInt64);
						default: break;
					}
					break;
				case BsonType.Int64:
					switch (v2.BsonType)
					{
						case BsonType.Int32:
							return new BsonInt64(v1.AsInt64 | (uint)v2.AsInt32);
						case BsonType.Int64:
							return new BsonInt64(v1.AsInt64 | v2.AsInt64);
						default: break;
					}
					break;
				default:
					break;
			}
			throw new InvalidOperationException("Bitwise OR expects Int32 or Int64 values.");
		}
		public static BsonValue BitwiseXor(BsonValue v1, BsonValue v2)
		{
			switch (v1.BsonType)
			{
				case BsonType.Int32:
					switch (v2.BsonType)
					{
						case BsonType.Int32:
							return new BsonInt32(v1.AsInt32 ^ v2.AsInt32);
						case BsonType.Int64:
							return new BsonInt64((uint)v1.AsInt32 ^ v2.AsInt64);
						default: break;
					}
					break;
				case BsonType.Int64:
					switch (v2.BsonType)
					{
						case BsonType.Int32:
							return new BsonInt64(v1.AsInt64 ^ (uint)v2.AsInt32);
						case BsonType.Int64:
							return new BsonInt64(v1.AsInt64 ^ v2.AsInt64);
						default: break;
					}
					break;
				default:
					break;
			}
			throw new InvalidOperationException("Bitwise XOR expects Int32 or Int64 values.");
		}
	}
	static class MyArray
	{
		public static void ValidateNames(this BsonArray that)
		{
			foreach (var v in that)
				v.ValidateNames();
		}
		public static void AddToSet(this BsonArray that, BsonValue value)
		{
			if (!that.ContainsByCompareTo(value))
				that.Add(value);
		}
		public static void AddToSetEach(this BsonArray that, BsonArray value)
		{
			foreach (var it in value)
				if (!that.ContainsByCompareTo(it))
					that.Add(it);
		}
		public static bool ContainsByCompareTo(this BsonArray that, BsonValue value)
		{
			foreach (var v in that)
				if (v.CompareTo(value) == 0)
					return true;
			return false;
		}
		// >= n - add nulls and value; else return false; < 0 - v2.6: error; v2.4: insert at 0.
		public static bool InsertOutOfRange(this BsonArray that, int index, Func<BsonValue> value)
		{
			if (index < 0)
				throw new InvalidOperationException(string.Format(null, "Cannot insert at index ({0}).", index));

			if (index < that.Count)
				return false;

			for (int i = that.Count; i < index; ++i)
				that.Add(BsonNull.Value);
			that.Add(value());
			return true;
		}
		// Gets an iterator of matching values for a key with dots.
		public static IEnumerable<BsonValue> GetNestedValues(this BsonArray that, string key)
		{
			int index;

			int dot = key.IndexOf('.');
			if (dot < 0 && int.TryParse(key, out index))
			{
				// single arrayIndex, return a valid item
				if (index >= 0 && index < that.Count)
					yield return that[index];
			}
			else if (dot >= 0 && int.TryParse(key.Substring(0, dot), out index))
			{
				// the first key is arrayIndex, skip out of range
				if (index < 0 || index >= that.Count)
					yield break;

				// pass the rest in a document
				var value = that[index];
				if (value.BsonType == BsonType.Document)
					foreach (var it in value.AsBsonDocument.GetNestedValues(key.Substring(dot + 1)))
						yield return it;
			}
			else
			{
				// pass the key to documents
				foreach (var it in that)
				{
					if (it.BsonType == BsonType.Document)
						foreach (var value in it.AsBsonDocument.GetNestedValues(key))
							yield return value;
				}
			}
		}
		// 2 arguments - skip, count
		public static BsonArray Slice(this BsonArray array, params int[] args)
		{
			int s;
			int n = args[1];

			if (n == 0)
				return new BsonArray();

			if (n < 0)
			{
				s = array.Count + n;
				n = -n;
			}
			else
			{

				s = args[0];
				if (s < 0)
				{
					s = Math.Max(array.Count + s, 0);
				}
				else if (s >= array.Count)
				{
					return new BsonArray();
				}
			}

			if (s == 0 && n >= array.Count)
				return array;

			int e = Math.Min(s + n, array.Count);

			var r = new BsonArray();
			for (int i = s; i < e; ++i)
				r.Add(array[i]);

			return r;
		}
	}
	class ResolvedDocumentPath
	{
		public BsonDocument Document;
		public string Key;
		public BsonArray Array;
		public int Index;
	}
	[Flags]
	enum ResolvePathOptions
	{
		None = 0,
		NoArray = 1,
		YesNegativeIndex = 2
	}
	static class MyDocument
	{
		public static void ValidateNames(this BsonDocument that)
		{
			foreach (var e in that.Elements)
			{
				var name = e.Name;
				if (name.Length == 0 || name[0] == '$' || name.IndexOf('.') >= 0)
					throw new InvalidOperationException(string.Format(null, @"Invalid document element name: ""{0}"".", name));

				e.Value.ValidateNames();
			}
		}
		public static BsonValue EnsureId(this BsonDocument that)
		{
			BsonValue id;
			if (that.TryGetValue(MyValue.Id, out id))
				return id;

			id = new BsonObjectId(ObjectId.GenerateNewId());
			that.InsertAt(0, new BsonElement(MyValue.Id, id));
			return id;
		}
		// Gets matching values for a key with dots or an empty set if nothing is found.
		// For arrays compiler gets an iterator which can be stopped on a first queried value.
		public static IEnumerable<BsonValue> GetNestedValues(this BsonDocument that, string key)
		{
			int index;
			BsonValue value;
			if ((index = key.IndexOf('.')) < 0)
				return that.TryGetValue(key, out value) ? new BsonValue[] { value } : new BsonValue[] { };

			var key1 = key.Substring(0, index);
			if (!that.TryGetValue(key1, out value))
				return new BsonValue[] { };

			var key2 = key.Substring(index + 1);

			if (value.BsonType == BsonType.Document)
				return value.AsBsonDocument.GetNestedValues(key2);

			if (value.BsonType != BsonType.Array)
				return new BsonValue[] { };

			if (value.BsonType == BsonType.Array)
				return value.AsBsonArray.GetNestedValues(key2);

			return new BsonValue[] { };
		}
		public static ResolvedDocumentPath EnsurePath(this BsonDocument that, string path)
		{
			var r = new ResolvedDocumentPath();

			if (path.IndexOf('.') < 0)
			{
				r.Document = that;
				r.Key = path;
				return r;
			}

			var document = that;
			var keys = path.Split('.');
			int last = keys.Length - 1;
			for (int i = 0; i <= last; ++i)
			{
				var key = keys[i];
				if (i == last)
				{
					r.Document = document;
					r.Key = key;
					return r;
				}

				BsonValue value;
				if (!document.TryGetValue(key, out value))
				{
					var newDocument = new BsonDocument();
					document.Add(key, newDocument);
					document = newDocument;
					continue;
				}

				if (value.BsonType == BsonType.Document)
				{
					document = value.AsBsonDocument;
					continue;
				}

				int arrayIndex;
				if (value.BsonType == BsonType.Array && int.TryParse(keys[i + 1], out arrayIndex))
				{
					var array = value.AsBsonArray;
					if (i == last - 1)
					{
						r.Array = array;
						r.Index = arrayIndex;
						return r;
					}

					if (!array.InsertOutOfRange(arrayIndex, () => document = new BsonDocument()))
					{
						var value2 = array[arrayIndex];
						if (value2.BsonType != BsonType.Document)
							throw new InvalidOperationException(string.Format(null, "Array item at ({0}) in ({1}) is not a document.", arrayIndex, path));

						document = value2.AsBsonDocument;
					}
					++i;
					continue;
				}

				throw new InvalidOperationException(string.Format(null, "Field ({0}) in ({1}) is not a document.", key, path));
			}

			return null;
		}
		// Returns one of:
		// - Document and Key, Key may be missing
		// - Array and Index, Index is always valid
		public static ResolvedDocumentPath ResolvePath(this BsonDocument that, string path, ResolvePathOptions options = ResolvePathOptions.None)
		{
			var r = new ResolvedDocumentPath();

			if (path.IndexOf('.') < 0)
			{
				r.Document = that;
				r.Key = path;
				return r;
			}

			var document = that;
			var keys = path.Split('.');
			int last = keys.Length - 1;
			for (int i = 0; i <= last; ++i)
			{
				var key = keys[i];
				if (i == last)
				{
					r.Document = document;
					r.Key = key;
					return r;
				}

				BsonValue value;
				if (!document.TryGetValue(key, out value))
					return null;

				if (value.BsonType == BsonType.Document)
				{
					document = value.AsBsonDocument;
					continue;
				}

				int arrayIndex;
				if (value.BsonType != BsonType.Array || !int.TryParse(keys[i + 1], out arrayIndex))
					return null;

				if ((options & ResolvePathOptions.NoArray) != ResolvePathOptions.None)
					throw new InvalidOperationException("Array indexes are not supported.");

				//_140322_065506
				if (arrayIndex < 0)
				{
					if ((options & ResolvePathOptions.YesNegativeIndex) != ResolvePathOptions.None)
						return null;
					throw new InvalidOperationException(string.Format(null, "Invalid negative array index in ({0}).", path));
				}

				var array = value.AsBsonArray;
				if (arrayIndex >= array.Count)
					return null;

				if (i == last - 1)
				{
					r.Array = array;
					r.Index = arrayIndex;
					return r;
				}

				var value2 = array[arrayIndex];
				if (value2.BsonType != BsonType.Document)
					return null;

				document = value2.AsBsonDocument;
				++i;
			}

			return null;
		}
	}
}
