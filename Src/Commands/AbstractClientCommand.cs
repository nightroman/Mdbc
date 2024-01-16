
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

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
