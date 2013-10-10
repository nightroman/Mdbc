
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
	public abstract class AbstractCollectionCommand : PSCmdlet
	{
		[Parameter]
		[ValidateNotNull]
		public MongoCollection Collection
		{
			get
			{
				if (_Collection == null)
				{
					_Collection = GetVariableValue(Actor.CollectionVariable) as MongoCollection;
					if (_Collection == null) throw new PSArgumentException("Specify a collection by the parameter or variable Collection.");
				}
				return _Collection;
			}
			set
			{
				_Collection = value;
			}
		}
		MongoCollection _Collection;

		protected void WriteException(Exception value, object target)
		{
			WriteError(new ErrorRecord(value, "Driver", ErrorCategory.WriteError, target));
		}
	}
}
