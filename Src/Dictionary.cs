
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;

namespace Mdbc
{
	public class Dictionary : IDictionary, IConvertibleToBsonDocument
	{
		readonly BsonDocument _document;
		public Dictionary()
		{
			_document = new BsonDocument();
		}
		public Dictionary(object id)
		{
			_document = new BsonDocument();
			_document.Add(MyValue.Id, BsonValue.Create(id));
		}
		public Dictionary(IConvertibleToBsonDocument document)
		{
			if (document == null) throw new ArgumentNullException(nameof(document));
			_document = document.ToBsonDocument();
		}
		public BsonDocument ToBsonDocument()
		{
			return _document;
		}
		public string Print()
		{
			var writer = new StringWriter();
			var args = new JsonWriterSettings() { Indent = true };
			using (var json = new JsonWriter(writer, args))
				BsonSerializer.Serialize(json, typeof(BsonDocument), _document);
			return writer.ToString();
		}
		#region IDictionary
		public bool IsFixedSize
		{
			get { return IsReadOnly; }
		}
		public bool IsReadOnly
		{
			get { return _document is RawBsonDocument; }
		}
		public bool IsSynchronized { get { return false; } }
		public int Count { get { return _document.ElementCount; } }
		public ICollection Keys { get { return _document.Names.ToArray(); } }
		public ICollection Values { get { return _document.Values.Select(Actor.ToObject).ToArray(); } }
		public object SyncRoot { get { return null; } }
		public void CopyTo(Array array, int index)
		{
			throw new NotImplementedException();
		}
		public object this[object key]
		{
			get
			{
				if (key == null) throw new ArgumentNullException(nameof(key));
				BsonValue value;
				return _document.TryGetValue(key.ToString(), out value) ? Actor.ToObject(value) : null;
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
		public void Add(object key, object value)
		{
			if (key == null) throw new ArgumentNullException(nameof(key));
			_document.Add(key.ToString(), Actor.ToBsonValue(value));
		}
		public bool Contains(object key)
		{
			if (key == null) throw new ArgumentNullException(nameof(key));
			return _document.Contains(key.ToString());
		}
		public void Clear()
		{
			_document.Clear();
		}
		public IDictionaryEnumerator GetEnumerator()
		{
			return new DocumentEnumerator(_document.GetEnumerator());
		}
		IEnumerator IEnumerable.GetEnumerator()
		{
			return GetEnumerator();
		}
		public override string ToString()
		{
			return _document.ToString();
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
	}
}
