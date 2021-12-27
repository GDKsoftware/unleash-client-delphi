# unleash-client-delphi

## Requirements

* Delphi 10.3 or higher

## Using the unleash client for Delphi

This library was developed with the interfaces of the NodeJS client in mind.

### Initialization

```pascal
var
  Unleash: IUnleash;
  Config: TUnleashConfig;
begin
  Config.Default;
  Config.url := 'http://127.0.0.1:4242/';
  Config.appName := 'my-app-name';
  Config.instanceId := 'my-unique-instance-id';
  Config.prefixFilter := 'app.'; // optional
  Config.apiKey := 'user.production.12ab34cd56ef57ab89cd'; // optional

  Unleash := TUnleash.Create;
  Unleash.Initialize(Config);
end;
```

### Example

```pascal
if Unleash.IsEnabled('app.ToggleX') then
begin
  // Feature implementation ...
end;
```

### Unleash context

```pascal
var
  Context: TUnleashContext;
begin
  Context.userId := '123';
  Context.remoteAddress := '127.0.0.1';

  if Unleash.IsEnabled('app.ToggleX', Context) then
  begin
    // Feature implementation ...
  end;
end;
```

### Default context

A slight difference with the NodeJS client, in this version we can also setup the
default context so it doesn't have to be passed to IsEnabled all the time.

```pascal
var
  Context: TUnleashContext;
begin
  Context.userId := '123';
  Context.remoteAddress := '127.0.0.1';

  Unleash.SetDefaultContext(Context);

  if Unleash.IsEnabled('app.ToggleX') then
  begin
    // Feature implementation ...
  end;
end;
```

## Supported strategies

* DefaultStrategy
* UserIdStrategy
* GradualRolloutUserIdStrategy
* GradualRolloutRandomStrategy
* RemoteAddressStrategy

## Differences with the nodejs client

* The DefaultContext is always used when no context is supplied to the `IsEnabled` function.
* There's no refresh rate of fetching features from the server, but you can implement your own timer or thread that may call `Unleash.Refresh;`
* There's no default backup option that allows for offline features, but you can implement your own through `Unleash.GetLatestFeaturesJson` and `Config.initialFeaturesJson := LastKnownOrDefaultFeaturesJson;`
* The default If-Modified behaviour causes an internal IDE Exception because of the 403 status-code when calling *Unleash.Refresh*, you can choose to disable If-Modified by setting `Config.noETag := False;`, although this is not recommended.
* The nodejs client supports custom headers to send along with the requests (and thus the Authorization header), we offer a simple `apiKey` setting.
* Metrics have not been implemented yet.
