
using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands;

/// <summary>
/// Commands with the Database parameter.
/// </summary>
public abstract class AbstractDatabaseCommand : Abstract
{
	IMongoDatabase _Database;

	[Parameter]
	public IMongoDatabase Database
	{
		get => _Database ??= ResolveDatabase();
		set => _Database = value;
	}
}
