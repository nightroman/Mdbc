
using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands;

public abstract class AbstractClientCommand : Abstract
{
	MongoClient _Client;
	[Parameter]
	public MongoClient Client
	{
		get => _Client ??= ResolveClient();
		set => _Client = value;
	}
}
