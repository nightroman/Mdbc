
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands
{
	public abstract class AbstractDatabaseCommand : Abstract
	{
		IMongoDatabase _Database;
		[Parameter]
		public IMongoDatabase Database
		{
			get
			{
				if (_Database == null)
				{
					_Database = Actor.BaseObject(GetVariableValue(Actor.DatabaseVariable)) as IMongoDatabase;
					if (_Database == null) throw new PSInvalidOperationException("Specify a database by the parameter or variable Database.");
				}
				return _Database;
			}
			set
			{
				_Database = value;
			}
		}
	}
}
