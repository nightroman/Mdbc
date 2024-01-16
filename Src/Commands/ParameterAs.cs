
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Management.Automation;

namespace Mdbc.Commands;

/// <summary>
/// Common parameter -As.
/// </summary>
class ParameterAs
{
	internal Type Type = typeof(Dictionary);
	internal bool IsSet;
	internal bool IsType;

	internal ParameterAs() { }

	internal void Set(object value)
	{
		if (value == null)
			return;

		IsSet = true;
		value = PS2.BaseObject(value);

		if (value is Type type)
		{
			IsType = true;
			Type = type;
			return;
		}

		if (value is OutputType alias || value is string str && Enum.TryParse(str, out alias))
		{
			switch (alias)
			{
				case OutputType.Default:
					Type = typeof(Dictionary);
					return;
				case OutputType.PS:
					Type = typeof(PSObject);
					return;
			}
		}

		Type = LanguagePrimitives.ConvertTo<Type>(value);
		IsType = true;
	}
}
