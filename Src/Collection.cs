﻿
using MongoDB.Bson;
using System.Collections;

namespace Mdbc;

//! sync logic with Dictionary
public sealed class Collection : IList
{
	readonly BsonArray _array;

	public Collection()
	{
		_array = [];
	}

	/// <summary>
	/// Wrapper.
	/// </summary>
	public Collection(BsonArray array)
	{
		_array = array ?? throw new ArgumentNullException(nameof(array));
	}

	[Obsolete("Designed for scripts.")]
	public Collection(ICollection collection)
	{
		if (collection == null)
			throw new ArgumentNullException(nameof(collection));

		if (collection is Collection that)
		{
			_array = (BsonArray)that._array.DeepClone();
		}
		else
		{
			_array = new BsonArray(collection.Count);
			foreach (var item in collection)
				_array.Add(Actor.ToBsonValue(item));
		}
	}

	public BsonArray ToBsonArray()
	{
		return _array;
	}

	#region Object
	public override bool Equals(object obj)
	{
		return obj is Collection arr && _array.Equals(arr._array);
	}

	public override int GetHashCode()
	{
		return _array.GetHashCode();
	}

	public override string ToString()
	{
		return _array.ToString();
	}
	#endregion

	public IEnumerator GetEnumerator()
	{
		return _array.Select(Actor.ToObject).GetEnumerator();
	}

	public bool IsSynchronized { get { return false; } }

	public object SyncRoot { get { return null; } }

	public int Count { get { return _array.Count; } }

	public void CopyTo(Array array, int index)
	{
		if (array == null) throw new ArgumentNullException(nameof(array));
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

	// PS friendly Add
	public void Add(object value)
	{
		_array.Add(Actor.ToBsonValue(value));
	}

	// IList.Add, bad in PS
	int IList.Add(object value)
	{
		_array.Add(Actor.ToBsonValue(value));
		return _array.Count - 1;
	}
}
