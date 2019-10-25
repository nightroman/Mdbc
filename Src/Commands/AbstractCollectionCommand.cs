
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System;
using System.Management.Automation;

namespace Mdbc.Commands
{
	public abstract class AbstractCollectionCommand : Abstract
	{
		IMongoCollection<BsonDocument> _Collection;
		[Parameter]
		[ValidateNotNull]
		public IMongoCollection<BsonDocument> Collection
		{
			get
			{
				if (_Collection == null)
				{
					_Collection = Actor.BaseObject(GetVariableValue(Actor.CollectionVariable)) as IMongoCollection<BsonDocument>;
					if (_Collection == null) throw new PSInvalidOperationException("Specify a collection by the parameter or variable Collection.");
				}
				return _Collection;
			}
			set
			{
				_Collection = value;
			}
		}
		protected static void ThrowNotImplementedForFiles(string what)
		{
			throw new NotImplementedException(what + " is not implemented for data files.");
		}
	}
}
