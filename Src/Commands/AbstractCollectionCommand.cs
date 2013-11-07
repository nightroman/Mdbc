
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
using MongoDB.Driver;

namespace Mdbc.Commands
{
	public abstract class AbstractCollectionCommand : Abstract
	{
		[Parameter]
		[ValidateNotNull]
		public object Collection
		{
			get
			{
				return _Collection;
			}
			set
			{
				SetCollection(value);
			}
		}
		ICollectionHost _Collection;
		void SetCollection(object value)
		{
			if (value == null)
			{
				value = GetVariableValue(Actor.CollectionVariable);
				if (value == null)
					throw new PSArgumentException("Specify a collection by the parameter or variable Collection.");
			}

			value = Actor.BaseObject(value);

			var mc = value as MongoCollection;
			if (mc != null)
			{
				_Collection = new MongoCollectionHost(mc);
				return;
			}
			
			var fc = value as FileCollection;
			if (fc != null)
			{
				_Collection = fc;
				return;
			}

			throw new PSArgumentException("Unexpected type of parameter or variable Collection.");
		}
		internal ICollectionHost TargetCollection
		{
			get
			{
				if (_Collection == null)
					SetCollection(null);

				return _Collection;
			}
		}
		protected static void ThrowNotImplementedForFiles(string what)
		{
			throw new NotImplementedException(what + " is not implemented for data files.");
		}
	}
}
