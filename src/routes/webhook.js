const express = require('express');
const router = express.Router();
const EventBus = require('../bin/event_bus');


router.post("/:org_id", (req, res) => {
    try {
        const wh_data = req.body;
        const topic = wh_data.topic;
        console.info('\x1b[32mWebhook received\x1b[0m for org ' + req.params['org_id'] + " on topic " + topic);
        EventBus.emit('webhook', {
            org_id: req.params['org_id'],
            topic: topic,
            message: wh_data
        });
    } catch (e) {
        console.log("WEBHOOK COLLECTOR ERROR:")
        console.log(e)
        console.log(req.body)
    } finally {
        res.send()
    }
})

module.exports = router;