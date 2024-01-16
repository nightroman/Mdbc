
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands;

/// <summary>
/// Commands with the Database and Session parameters.
/// </summary>
public abstract class AbstractDatabaseCommand2 : AbstractSessionCommand
{
	IMongoDatabase _Database;

	[Parameter]
	public IMongoDatabase Database
	{
		get => _Database ??= ResolveDatabase();
		set => _Database = value;
	}

	protected override IMongoClient MyClient => Database.Client;
}
