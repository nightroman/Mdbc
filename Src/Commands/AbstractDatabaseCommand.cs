
// Copyright (c) 2011-2016 Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands
{
	public abstract class AbstractDatabaseCommand : Abstract
	{
		[Parameter]
		public MongoDatabase Database
		{
			get
			{
				if (_Database == null)
				{
					_Database = GetVariableValue(Actor.DatabaseVariable) as MongoDatabase;
					if (_Database == null) throw new PSArgumentException("Specify a database by the parameter or variable Database.");
				}
				return _Database;
			}
			set
			{
				_Database = value;
			}
		}
		MongoDatabase _Database;
	}
}
