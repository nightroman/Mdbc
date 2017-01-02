
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

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
