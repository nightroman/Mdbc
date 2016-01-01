
// Copyright (c) 2011-2016 Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections;
using System.Linq;
using MongoDB.Bson;

namespace Mdbc
{
	public sealed class Collection : IList
	{
		readonly BsonArray _array;
		public Collection()
		{
			_array = new BsonArray();
		}
		public Collection(BsonArray array)
		{
			_array = array;
		}
		public BsonArray Array()
		{
			return _array;
		}
		public void Dispose()
		{
			var dispose = _array as IDisposable;
			if (dispose != null)
				dispose.Dispose();
		}
		public IEnumerator GetEnumerator()
		{
			return _array.Select(Actor.ToObject).GetEnumerator();
		}
		public bool IsSynchronized { get { return false; } }
		public object SyncRoot { get { return null; } }
		public int Count { get { return _array.Count; } }
		public void CopyTo(Array array, int index)
		{
			if (array == null) throw new ArgumentNullException("array");
			foreach (var v in this)
				array.SetValue(v, index++);
		}
		public bool IsFixedSize
		{
			get { return IsReadOnly; }
		}
		public bool IsReadOnly
		{
			get { return _array is RawBsonArray; }
		}
		public object this[int index]
		{
			get
			{
				return Actor.ToObject(_array[index]);
			}
			set
			{
				_array[index] = Actor.ToBsonValue(value);
			}
		}
		public void RemoveAt(int index)
		{
			_array.RemoveAt(index);
		}
		public void Remove(object value)
		{
			_array.Remove(Actor.ToBsonValue(value));
		}
		public void Insert(int index, object value)
		{
			_array.Insert(index, Actor.ToBsonValue(value));
		}
		public int IndexOf(object value)
		{
			return _array.IndexOf(Actor.ToBsonValue(value));
		}
		public void Clear()
		{
			_array.Clear();
		}
		public bool Contains(object value)
		{
			return _array.Contains(Actor.ToBsonValue(value));
		}
		public int Add(object value)
		{
			_array.Add(Actor.ToBsonValue(value));
			return _array.Count - 1;
		}
	}
}
