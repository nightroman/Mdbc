
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
using System.Collections;
using System.Linq;
using MongoDB.Bson;

namespace Mdbc
{
	public class Collection : IList
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
		public IEnumerator GetEnumerator()
		{
			return _array.Select(Actor.ToObject).GetEnumerator();
		}
		public bool IsSynchronized { get { return false; } }
		public object SyncRoot { get { return null; } }
		public int Count { get { return _array.Count; } }
		public void CopyTo(Array array, int index)
		{
			throw new NotImplementedException();
		}
		public bool IsFixedSize { get { return false; } }
		public bool IsReadOnly { get { return false; } }
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
