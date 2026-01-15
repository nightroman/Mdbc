
using MongoDB.Driver;
using System.Management.Automation;
using System.Reflection;

namespace Mdbc.Commands;

public abstract class AbstractSessionCommand : Abstract, IDisposable
{
	bool _dispose;
	bool _disposed;
	IClientSessionHandle _Session;

	//! ThreadStatic and `= new Stack()` fails in Split-Pipeline
	[ThreadStatic]
	static Stack<IClientSessionHandle> _DefaultSessions_;
	static Stack<IClientSessionHandle> DefaultSessions => _DefaultSessions_ ??= new Stack<IClientSessionHandle>();

	internal static void PushDefaultSession(IClientSessionHandle session) => DefaultSessions.Push(session);
	internal static IClientSessionHandle PopDefaultSession() => DefaultSessions.Pop();

	//! 2019-12-04 #33 Do not use MongoClient.StartSession(), i.e. true session as implicit, some servers do not support sessions. Hack internal method.
	//! 2026-01-15 Driver 3.5.2 does not have this internal method, so revert to StartSession().
	IClientSessionHandle StartSession()
	{
		try
		{
			return MyClient.StartSession();
		}
		catch (TargetInvocationException ex)
		{
			if (ex.InnerException == null)
				throw;
			else
				throw ex.InnerException;
		}
	}

	[Parameter]
	public IClientSessionHandle Session
	{
		get
		{
			if (_Session == null)
			{
				if (DefaultSessions.Count == 0)
				{
					// create implicit session
					_Session = StartSession();
					_dispose = true;
				}
				else
				{
					// use current default session
					_Session = DefaultSessions.Peek();
				}
			}
			return _Session;
		}
		set
		{
			if (_Session != null)
				throw new InvalidOperationException("Session cannot be set twice.");

			_Session = value;
		}
	}

	protected abstract IMongoClient MyClient { get; }

	public void Dispose()
	{
		Dispose(true);
		GC.SuppressFinalize(this);
	}

	protected virtual void Dispose(bool disposing)
	{
		if (_disposed)
			return;

		if (disposing && _dispose)
			_Session.Dispose();

		_disposed = true;
	}
}
