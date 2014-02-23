
/* Copyright 2011-2014 Roman Kuzmin
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
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using MongoDB.Bson;

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
			if (document == null) throw new ArgumentNullException("document");
			_document = document.ToBsonDocument();
		}
		public BsonDocument ToBsonDocument()
		{
			return _document;
		}
		public void Dispose()
		{
			var dispose = _document as IDisposable;
			if (dispose != null)
				dispose.Dispose();
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
				if (key == null) throw new ArgumentNullException("key");
				return Actor.ToObject(_document.GetValue(key.ToString()));
			}
			set
			{
				if (key == null) throw new ArgumentNullException("key");
				_document.Set(key.ToString(), Actor.ToBsonValue(value));
			}
		}
		public void Remove(object key)
		{
			if (key == null) throw new ArgumentNullException("key");
			_document.Remove(key.ToString());
		}
		public void Add(object key, object value)
		{
			if (key == null) throw new ArgumentNullException("key");
			_document.Add(key.ToString(), Actor.ToBsonValue(value));
		}
		public bool Contains(object key)
		{
			if (key == null) throw new ArgumentNullException("key");
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
	public sealed class LazyDictionary : Dictionary
	{
		public LazyDictionary(LazyBsonDocument value) : base(value) { }
	}
	public sealed class RawDictionary : Dictionary
	{
		public RawDictionary(RawBsonDocument value) : base(value) { }
	}
}
