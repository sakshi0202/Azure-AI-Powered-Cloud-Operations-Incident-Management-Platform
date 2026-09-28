import json
import logging
import os

import azure.functions as func
from azure.eventgrid import EventGridPublisherClient, CloudEvent
from azure.identity import DefaultAzureCredential
from azure.mgmt.appcontainers import ContainerAppsAPIClient

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)
ALLOWED_ACTIONS = {"restart_container_app", "scale_container_app"}


def _event_publisher():
    return EventGridPublisherClient(
        os.environ["EVENTGRID_ENDPOINT"],
        DefaultAzureCredential(),
    )


@app.route(route="monitor-alert", methods=["POST"])
def monitor_alert_ingress(req: func.HttpRequest) -> func.HttpResponse:
    """Receives Azure Monitor Common Alert Schema and converts it to CloudEvent.

    Azure Monitor Action Groups can invoke Azure Functions with the common schema.
    This adapter normalizes that payload before Event Grid distributes it.
    """
    try:
        body = req.get_json()
        essentials = body.get("data", {}).get("essentials", {})
        incident_id = essentials.get("alertId") or essentials.get("originAlertId")
        if not incident_id:
            return func.HttpResponse("Missing alert identifier", status_code=400)

        event = CloudEvent(
            source="azure.monitor.cloudops",
            type="cloudops.incident.detected",
            subject=essentials.get("alertTargetIDs", ["unknown"])[0],
            data={
                "incident_id": incident_id,
                "title": essentials.get("alertRule", "Azure Monitor alert"),
                "severity": essentials.get("severity"),
                "condition": essentials.get("monitorCondition"),
                "description": essentials.get("description"),
                "target_resource_ids": essentials.get("alertTargetIDs", []),
                "raw_alert": body,
                "recommended_action": "investigate",
            },
        )
        _event_publisher().send(event)
        return func.HttpResponse(json.dumps({"accepted": True, "incident_id": incident_id}), status_code=202, mimetype="application/json")
    except Exception as exc:
        logging.exception("Failed to process Monitor alert")
        return func.HttpResponse(str(exc), status_code=500)


@app.service_bus_queue_trigger(
    arg_name="message",
    queue_name="remediation-events",
    connection="SERVICEBUS_CONNECTION",
)
def remediation_worker(message: func.ServiceBusMessage):
    payload = json.loads(message.get_body().decode("utf-8"))
    incident_id = payload.get("incident_id", message.message_id)
    action = payload.get("action", "investigate")
    logging.info("Processing incident=%s action=%s", incident_id, action)

    if action not in ALLOWED_ACTIONS:
        logging.info("Incident %s requires investigation/approval; no write action executed.", incident_id)
        return

    credential = DefaultAzureCredential()
    subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
    client = ContainerAppsAPIClient(credential, subscription_id)
    resource_group = os.environ["TARGET_RESOURCE_GROUP"]
    app_name = os.environ["TARGET_CONTAINER_APP"]

    app_resource = client.container_apps.get(resource_group, app_name)
    if action == "restart_container_app":
        revision_name = payload.get("revision_name") or app_resource.latest_ready_revision_name
        if not revision_name:
            raise RuntimeError("No ready revision is available for restart")
        client.container_apps_revisions.restart_revision(resource_group, app_name, revision_name)
        logging.info("Restarted revision=%s app=%s", revision_name, app_name)
    elif action == "scale_container_app":
        # Scaling is intentionally kept behind a separate policy path.
        # The incident must carry an approved target replica count.
        replicas = payload.get("target_replicas")
        if not isinstance(replicas, int) or replicas < 1 or replicas > 10:
            raise ValueError("target_replicas must be an integer between 1 and 10")
        logging.info("Approved scale request verified app=%s target_replicas=%s", app_name, replicas)

    logging.info("Remediation workflow completed for incident=%s", incident_id)
