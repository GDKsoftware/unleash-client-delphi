unit Unleash;

interface

uses
  Unleash.Interfaces,
  Unleash.Rest,
  Unleash.Types,
  SyncObjs,
  JSON,
  System.Generics.Collections;

type
  TUnleash = class(TInterfacedObject, IUnleash)
  protected
    FConfig: TUnleashConfig;
    FRestConnection: TRestConnection;
    FDefaultContext: TUnleashContext;
    FFeatures: TDictionary<string, TUnleashFeature>;
    FLastETag: string;
    FErrorFetchingFeatures: Boolean;
    FReceivedFeatures: Boolean;
    FLastError: string;
    FLastFeaturesJson: string;
    FRandomRoll: Integer;

    FLock: TCriticalSection;

    procedure Finalize;
    procedure ClearFeatures;

    procedure LoadDefaultFeatures;

    procedure ProcessFeatures(const Json: TJSONObject);
    procedure FetchFeatures;

    function IsEnabledByStrategy(const Context: TUnleashContext; const Settings: TUnleashFeature): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Initialize(const Configuration: TUnleashConfig);
    procedure SetDefaultContext(const Context: TUnleashContext);
    function IsEnabled(const ToggleName: string): Boolean; overload;
    function IsEnabled(const ToggleName: string; const Context: TUnleashContext): Boolean; overload;

    procedure Refresh;
    function GetLatestFeaturesJson: string;
    function GetLastError: string;
  end;

implementation

uses
  System.SysUtils,
  Rest.Types, System.Classes;

const
  c_StrategyDefault = 'default';
  c_StrategyUserWithId = 'userWithId';
  c_StrategyGradualRolloutRandom = 'gradualRolloutRandom';
  c_StrategyGradualRolloutUserId = 'gradualRolloutUserId';
  c_StrategyRemoteAddress = 'remoteAddress';

type
  EUnleashException = class(Exception);
  ENotAuthorized = class(EUnleashException);


{ TUnleash }

constructor TUnleash.Create;
begin
  FLock := TCriticalSection.Create;
  FRandomRoll := 1 + Random(100);
end;

destructor TUnleash.Destroy;
begin
  FLock.Enter;
  try
    Finalize;
  finally
    FLock.Release;
    FLock.Free;
  end;

  inherited;
end;

procedure TUnleash.Finalize;
begin
  if Assigned(FFeatures) then
  begin
    ClearFeatures;

    FreeAndNil(FFeatures);
  end;

  FreeAndNil(FRestConnection);
end;

procedure TUnleash.ClearFeatures;
var
  Feature: TUnleashFeature;
begin
  for Feature in FFeatures.Values do
    Feature.Free;

  FFeatures.Clear;
end;

function TUnleash.GetLastError: string;
begin
  if FErrorFetchingFeatures then
    Result := FLastError
  else
    Result := EmptyStr;
end;

function TUnleash.GetLatestFeaturesJson: string;
begin
  Result := FLastFeaturesJson;
end;

procedure TUnleash.Initialize(const Configuration: TUnleashConfig);
begin
  Finalize;

  FConfig := Configuration;
  FRestConnection := TRestConnection.Create(FConfig.url);
  FFeatures := TDictionary<string, TUnleashFeature>.Create;

  LoadDefaultFeatures;
  FetchFeatures;
end;

procedure TUnleash.LoadDefaultFeatures;
var
  Json: TJSONObject;
begin
  if FConfig.initialFeaturesJson <> '' then
  begin
    Json := TJSONObject.ParseJSONValue(FConfig.initialFeaturesJson) as TJSONObject;
    try
      ProcessFeatures(Json);
    finally
      Json.Free;
    end;
  end;
end;

procedure TUnleash.ProcessFeatures(const Json: TJSONObject);
var
  JsonFeatures: TJSONArray;
  JsonFeature: TJSONValue;
  JsonStrategy: TJSONValue;
  JsonStrategies: TJSONArray;
  JsonParameters: TJSONObject;
  Settings: TUnleashFeature;
  Strategy: TUnleashStrategy;
  CustomPair: TJSONPair;
begin
  if not Assigned(Json) then Exit;

  ClearFeatures;

  FLastFeaturesJson := Json.ToJSON;

  JsonFeatures := Json.GetValue('features') as TJSONArray;
  for JsonFeature in JsonFeatures do
  begin
    Settings := TUnleashFeature.Create;
    Settings.Name := JsonFeature.GetValue<TJSONValue>('name').Value;
    if JsonFeature.FindValue('description') <> nil then
      Settings.Description := JsonFeature.GetValue<TJSONValue>('description').Value;
    Settings.Enabled := JsonFeature.GetValue<TJSONValue>('enabled').AsType<Boolean>;

    if JsonFeature.FindValue('strategies') <> nil then
    begin
      JsonStrategies := JsonFeature.GetValue<TJSONArray>('strategies');
      for JsonStrategy in JsonStrategies do
      begin
        Strategy := TUnleashStrategy.Create;
        Strategy.Name := JsonStrategy.GetValue<TJSONValue>('name').Value;
        Strategy.Ids.Options := [soStrictDelimiter];

        JsonParameters := JsonStrategy.GetValue<TJSONObject>('parameters', nil);
        if Assigned(JsonParameters) then
        begin
          if JsonParameters.FindValue('userIds') <> nil then
          begin
            Strategy.Ids.CommaText := JsonParameters.GetValue<TJSONValue>('userIds').Value;
          end
          else if JsonParameters.FindValue('hostNames') <> nil then
          begin
            Strategy.Ids.CommaText := JsonParameters.GetValue<TJSONValue>('hostNames').Value;
          end
          else if JsonParameters.FindValue('IPs') <> nil then
          begin
            Strategy.Ids.CommaText := JsonParameters.GetValue<TJSONValue>('IPs').Value;
          end
          else if JsonParameters.FindValue('percentage') <> nil then
          begin
            Strategy.Percentage := StrToIntDef(JsonParameters.GetValue<TJSONValue>('percentage').Value, 0);
          end
          else if JsonParameters.Count = 1 then
          begin
            CustomPair := JsonParameters.Pairs[0];
            Strategy.Ids.CommaText := TJsonValue(CustomPair.JsonValue).Value;
          end;
        end;
        Settings.Strategies.Add(Strategy);
      end;
    end;

    FFeatures.Add(Settings.Name, Settings);
  end;
end;

procedure TUnleash.Refresh;
begin
  FetchFeatures;
end;

procedure TUnleash.FetchFeatures;
begin
  FLock.Acquire;
  try
    FRestConnection.Request.Resource := 'api/client/features';

    if FConfig.prefixFilter <> '' then
      FRestConnection.Request.AddParameter('namePrefix', FConfig.prefixFilter)
    else
      FRestConnection.Request.Params.Clear;

    FRestConnection.Request.Method := TRESTRequestMethod.rmGET;
    FRestConnection.Request.Body.ClearBody;

    if not FConfig.noEtag and (FLastETag <> '') then
      FRestConnection.Request.AddParameter('If-None-Match', FLastETag, TRESTRequestParameterKind.pkHTTPHEADER, [TRESTRequestParameterOption.poDoNotEncode]);

    FRestConnection.Request.AddParameter('UNLEASH-APPNAME', FConfig.appName, TRESTRequestParameterKind.pkHTTPHEADER);
    FRestConnection.Request.AddParameter('UNLEASH-INSTANCEID', FConfig.instanceId, TRESTRequestParameterKind.pkHTTPHEADER);

    if FConfig.apiKey <> '' then
      FRestConnection.Request.AddParameter('Authorization', FConfig.apiKey, TRESTRequestParameterKind.pkHTTPHEADER, [poDoNotEncode]);

    FRestConnection.Request.Timeout := FConfig.timeout;

    try
      FRestConnection.Request.Execute;

      if FRestConnection.Response.StatusCode = 304 then
        Exit;

      if FRestConnection.Response.StatusCode = 401 then
        raise ENotAuthorized.Create('You must sign in order to use Unleash');

      FErrorFetchingFeatures := False;

      FLastETag := FRestConnection.Response.Headers.Values['ETag'];

      ProcessFeatures(FRestConnection.Response.JSONValue as TJSONObject);
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        FErrorFetchingFeatures := True;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TUnleash.IsEnabledByStrategy(const Context: TUnleashContext; const Settings: TUnleashFeature): Boolean;
var
  Strategy: TUnleashStrategy;
begin
  Result := False;
  if not Settings.Enabled then Exit;

  for Strategy in Settings.Strategies do
  begin
    if Strategy.Name = c_StrategyDefault then
    begin
      Result := True;
      break;
    end
    else if Strategy.Name = c_StrategyUserWithId then
    begin
      if Strategy.IsInIds(Context.userId) then
      begin
        Result := True;
        break;
      end;
    end
    else if Strategy.Name = c_StrategyGradualRolloutRandom then
    begin
      if FRandomRoll <= Strategy.Percentage then
      begin
        Result := True;
        break;
      end;
    end
    else if Strategy.Name = c_StrategyGradualRolloutUserId then
    begin
      // the Unleash api manual suggests to use Murmur, but this will have to do
      if Abs(Context.userId.GetHashCode mod 100) <= Strategy.Percentage then
      begin
        Result := True;
        break;
      end;
    end
    else if Strategy.Name = c_StrategyRemoteAddress then
    begin
      if Strategy.IsInIds(Context.remoteAddress) then
      begin
        Result := True;
        break;
      end;
    end
    else
    begin
      if Strategy.IsInIds(Context.customParam) then
      begin
        Result := True;
        break;
      end;
    end;
  end;
end;

function TUnleash.IsEnabled(const ToggleName: string; const Context: TUnleashContext): Boolean;
var
  Settings: TUnleashFeature;
begin
  Result := False;

  FLock.Acquire;
  try
    if FFeatures.TryGetValue(ToggleName, Settings) then
    begin
      if Settings.Strategies.Count = 0 then
      begin
        Result := Settings.Enabled;
      end
      else
      begin
        Result := IsEnabledByStrategy(Context, Settings);
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TUnleash.IsEnabled(const ToggleName: string): Boolean;
begin
  Result := IsEnabled(ToggleName, FDefaultContext);
end;

procedure TUnleash.SetDefaultContext(const Context: TUnleashContext);
begin
  FDefaultContext := Context;
end;

end.
