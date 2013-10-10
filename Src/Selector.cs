
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
using System.Collections.Generic;
using System.Management.Automation;

namespace Mdbc
{
	class Selector
	{
		public string DocumentName { get; private set; }
		public string PropertyName { get; private set; }
		ScriptBlock _ScriptBlock;
		PSCmdlet _Cmdlet;
		internal static IList<Selector> Create(IEnumerable values, PSCmdlet cmdlet)
		{
			var list = new List<Selector>();
			foreach (var value in values)
				if (value != null)
					list.Add(new Selector(value, cmdlet));

			return list;
		}
		internal object GetValue(object value)
		{
			using (new SetDollar(_Cmdlet.SessionState, value))
				return _ScriptBlock.InvokeReturnAsIs();
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
		Selector(object selector, PSCmdlet cmdlet)
		{
			_Cmdlet = cmdlet;

			var name = selector as string;
			if (name != null)
			{
				DocumentName = name;
				PropertyName = name;
				return;
			}

			IDictionary dictionary = selector as IDictionary;
			if (dictionary == null)
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
