
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;

namespace Mdbc
{
	class Selector
	{
		public string DocumentName { get; private set; }
		public string PropertyName { get; private set; }
		ScriptBlock _ScriptBlock;
		internal static IList<Selector> Create(IEnumerable values)
		{
			var list = new List<Selector>();
			foreach (var value in values)
			{
				if (value != null)
				{
					if (value is string name && name == "*")
					{
						list.Clear();
						break;
					}
					list.Add(new Selector(value));
				}
			}
			return list;
		}
		internal object GetValue(object value)
		{
			var r = PS2.InvokeWithContext(_ScriptBlock, value);
			switch (r.Count)
			{
				case 1: { return r[0]; }
				case 0: { return null; }
				default: { return r; }
			}
		}
		void SetExpression(object value)
		{
			PropertyName = value as string;
			if (PropertyName == null)
			{
				_ScriptBlock = value as ScriptBlock;
				if (_ScriptBlock == null)
					throw new ArgumentException("Expression must be specified by a string or a script block.");
			}
		}
		Selector(object selector)
		{
			if (selector is string name)
			{
				DocumentName = name;
				PropertyName = name;
				return;
			}

			if (!(selector is IDictionary dictionary))
				throw new ArgumentException("Property must be specified by a string or a dictionary.");

			if (dictionary.Count == 1)
			{
				foreach (DictionaryEntry de in dictionary)
				{
					DocumentName = de.Key.ToString();
					SetExpression(de.Value);
				}
				return;
			}

			if (dictionary.Count != 2)
				throw new ArgumentException("Property dictionary must contain 1 or 2 entries.");

			foreach (DictionaryEntry de in dictionary)
			{
				if ("Expression".StartsWith(de.Key.ToString(), StringComparison.OrdinalIgnoreCase))
				{
					SetExpression(de.Value);
				}
				else if ("Name".StartsWith(de.Key.ToString(), StringComparison.OrdinalIgnoreCase) || "Label".StartsWith(de.Key.ToString(), StringComparison.OrdinalIgnoreCase))
				{
					DocumentName = de.Value.ToString();
				}
			}

			if (DocumentName == null || (PropertyName == null && _ScriptBlock == null))
				throw new ArgumentException("Property info must be specified by a dictionary with two not null items: Name|Label and Expression.");
		}
	}
}
