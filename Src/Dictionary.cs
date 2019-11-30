
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

namespace Mdbc
{
	//! sync logic with Collection
	public sealed class Dictionary : IDictionary<string, object>, IDictionary, IConvertibleToBsonDocument
	{
		readonly BsonDocument _document;
		public Dictionary()
		{
			_document = new BsonDocument();
		}
		/// <summary>
		/// Wrapper.
		/// </summary>
		public Dictionary(BsonDocument document)
		{
			_document = document ?? throw new ArgumentNullException(nameof(document));
		}
		/// <summary>
		/// Deep clone or convert dictionaries.
		/// </summary>
		//! IDictionary, not just Mdbc.Dictionary, for assigning @{...} to [Mdbc.Dictionary] typed variables and members.
		[Obsolete("Designed for scripts.")]
		public Dictionary(IDictionary document)
		{
			if (document == null)
				throw new ArgumentNullException(nameof(document));

			if (document is Dictionary that)
				_document = (BsonDocument)that._document.DeepClone();
			else
				_document = Actor.ToBsonDocumentFromDictionary(document);
		}
		[Obsolete("Designed for scripts.")]
		public Dictionary(object value)
		{
			if (Environment.GetEnvironmentVariable("MdbcDictionaryLegacy") == "0")
				throw new InvalidOperationException("Used deprecated Mdbc.Dictionary(object)");

			value = Actor.BaseObject(value);
			if (value == null)
				throw new ArgumentNullException(nameof(value));

			if (value is Dictionary that)
			{
				_document = (BsonDocument)that._document.DeepClone();
			}
			else
			{
				var bson = Actor.ToBsonValue(value);
				if (bson.BsonType == BsonType.Document)
					_document = bson.AsBsonDocument;
				else
					_document = new BsonDocument(BsonId.Element(bson));
			}
		}
		public BsonDocument ToBsonDocument()
		{
			return _document;
		}
		public string Print()
		{
			return MyJson.PrintBsonDocument(_document);
		}

		#region Object
		public override bool Equals(object obj)
		{
			return obj is Dictionary dic && _document.Equals(dic._document);
		}
		public override int GetHashCode()
		{
			return _document.GetHashCode();
		}
		public override string ToString()
		{
			return _document.ToString();
		}
		#endregion

		#region Common
		public int Count
		{
			get { return _document.ElementCount; }
		}
		public bool IsReadOnly
		{
			get { return _document is RawBsonDocument; }
		}
		public void Clear()
		{
			_document.Clear();
		}
		#endregion

		#region ICollection
		bool ICollection.IsSynchronized
		{
			get { return false; }
		}
		object ICollection.SyncRoot
		{
			get { return null; }
		}
		void ICollection.CopyTo(Array array, int index)
		{
			throw new NotImplementedException();
		}
		#endregion

		#region ICollection2
		void ICollection<KeyValuePair<string, object>>.Add(KeyValuePair<string, object> item)
		{
			_document.Add(item.Key, Actor.ToBsonValue(item.Value));
		}
		bool ICollection<KeyValuePair<string, object>>.Contains(KeyValuePair<string, object> item)
		{
			return _document.Contains(item.Key);
		}
		void ICollection<KeyValuePair<string, object>>.CopyTo(KeyValuePair<string, object>[] array, int index)
		{
			throw new NotImplementedException();
		}
		bool ICollection<KeyValuePair<string, object>>.Remove(KeyValuePair<string, object> item)
		{
			var exists = _document.Contains(item.Key);
			_document.Remove(item.Key);
			return exists;
		}
		public IEnumerator<KeyValuePair<string, object>> GetEnumerator()
		{
			return new DocumentEnumerator2(_document.GetEnumerator());
		}
		class DocumentEnumerator2 : IEnumerator<KeyValuePair<string, object>>
		{
			readonly IEnumerator<BsonElement> _that;
			public DocumentEnumerator2(IEnumerator<BsonElement> that)
			{
				_that = that;
			}
			void IDisposable.Dispose() { }
			public KeyValuePair<string, object> Current { get { return new KeyValuePair<string, object>(_that.Current.Name, Actor.ToObject(_that.Current.Value)); } }
			object IEnumerator.Current { get { return Current; } }
			public bool MoveNext() { return _that.MoveNext(); }
			public void Reset() { _that.Reset(); }
		}
		#endregion

		#region IDictionary
		bool IDictionary.IsFixedSize
		{
			get { return _document is RawBsonDocument; }
		}
		ICollection IDictionary.Keys
		{
			get { return _document.Names.ToArray(); }
		}
		ICollection IDictionary.Values
		{
			get { return _document.Values.Select(Actor.ToObject).ToArray(); }
		}
		object IDictionary.this[object key]
		{
			get
			{
				if (key == null) throw new ArgumentNullException(nameof(key));
				return _document.TryGetValue(key.ToString(), out BsonValue value) ? Actor.ToObject(value) : null;
			}
			set
			{
				if (key == null) throw new ArgumentNullException(nameof(key));
				_document.Set(key.ToString(), Actor.ToBsonValue(value));
			}
		}
		public void Remove(object key)
		{
			if (key == null) throw new ArgumentNullException(nameof(key));
			_document.Remove(key.ToString());
		}
		void IDictionary.Add(object key, object value)
		{
			if (key == null) throw new ArgumentNullException(nameof(key));
			_document.Add(key.ToString(), Actor.ToBsonValue(value));
		}
		public bool Contains(object key)
		{
			if (key == null) throw new ArgumentNullException(nameof(key));
			return _document.Contains(key.ToString());
		}
		IDictionaryEnumerator IDictionary.GetEnumerator()
		{
			return new DocumentEnumerator(_document.GetEnumerator());
		}
		IEnumerator IEnumerable.GetEnumerator()
		{
			return new DocumentEnumerator(_document.GetEnumerator());
		}
		class DocumentEnumerator : IDictionaryEnumerator
		{
			readonly IEnumerator<BsonElement> _that;
			public DocumentEnumerator(IEnumerator<BsonElement> that)
			{
				_that = that;
			}
			public DictionaryEntry Entry { get { return new DictionaryEntry(_that.Current.Name, Actor.ToObject(_that.Current.Value)); } }
			public object Key { get { return _that.Current.Name; } }
			public object Value { get { return Actor.ToObject(_that.Current.Value); } }
			public object Current { get { return Entry; } }
			public void Reset() { _that.Reset(); }
			public bool MoveNext() { return _that.MoveNext(); }
		}
		#endregion

		#region IDictionary2
		public ICollection<string> Keys
		{
			get { return _document.Names.ToArray(); }
		}
		public ICollection<object> Values
		{
			get { return _document.Values.Select(Actor.ToObject).ToArray(); }
		}
		public object this[string key]
		{
			get
			{
				if (key == null) throw new ArgumentNullException(nameof(key));
				return _document.TryGetValue(key, out BsonValue value) ? Actor.ToObject(value) : null;
			}
			set
			{
				if (key == null) throw new ArgumentNullException(nameof(key));
				_document.Set(key, Actor.ToBsonValue(value));
			}
		}
		public void Add(string key, object value)
		{
			if (key == null) throw new ArgumentNullException(nameof(key));
			_document.Add(key, Actor.ToBsonValue(value));
		}
		public bool TryGetValue(string key, out object value)
		{
			if (_document.TryGetValue(key, out BsonValue value2))
			{
				value = Actor.ToObject(value2);
				return true;
			}
			else
			{
				value = null;
				return false;
			}
		}
		public bool ContainsKey(string key)
		{
			return _document.Contains(key);
		}
		//! private, do not want in PowerShell for returned bool
		bool IDictionary<string, object>.Remove(string key)
		{
			var exists = _document.Contains(key);
			_document.Remove(key);
			return exists;
		}
		#endregion
	}
}
