
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
using System.Management.Automation;
using MongoDB.Bson;

namespace Mdbc
{
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
				throw new InvalidCastException("Invalid value type. Expected types: int, long.");
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
				throw new InvalidCastException("Invalid value type. Expected types: int, long, double.");
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
	public enum OutputType
	{
		Default,
		Lazy,
		Raw,
		PS
	}
	class ParameterAs
	{
		internal readonly Type DeserializeType;
		public ParameterAs(PSObject value)
		{
			Actor.Register();
			
			if (value == null)
			{
				DeserializeType = typeof(Dictionary);
				return;
			}

			var type = value.BaseObject as Type;
			if (type != null)
			{
				DeserializeType = (Type)LanguagePrimitives.ConvertTo(value, typeof(Type), null);
				return;
			}

			switch ((OutputType)LanguagePrimitives.ConvertTo(value, typeof(OutputType), null))
			{
				case OutputType.Default:
					DeserializeType = typeof(Dictionary);
					return;
				case OutputType.Lazy:
					DeserializeType = typeof(LazyDictionary);
					return;
				case OutputType.Raw:
					DeserializeType = typeof(RawDictionary);
					return;
				case OutputType.PS:
					DeserializeType = typeof(PSObject);
					return;
			}
		}
	}
}
