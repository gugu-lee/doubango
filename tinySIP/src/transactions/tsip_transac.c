/*
* Copyright (C) 2010-2011 Mamadou Diop.
*
* Contact: Mamadou Diop <diopmamadou(at)doubango[dot]org>
*
* This file is part of Open Source Doubango Framework.
*
* DOUBANGO is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* DOUBANGO is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with DOUBANGO.
*
*/

/**@file tsip_transac.c
 * @brief SIP transaction base class as per RFC 3261 subclause 17.
 *
 * @author Mamadou Diop <diopmamadou(at)doubango[dot]org>
 *

 */
#include "tinysip/transactions/tsip_transac.h"

#include "tinysip/transports/tsip_transport_layer.h"
#include "tinysip/transactions/tsip_transac_layer.h"

#include "tinysip/transactions/tsip_transac_ist.h"
#include "tinysip/transactions/tsip_transac_nist.h"
#include "tinysip/transactions/tsip_transac_nict.h"
#include "tinysip/transactions/tsip_transac_ict.h"

#include "tsk_string.h"
#include "tsk_memory.h"
#include "tsk_debug.h"

// 为 Android 添加日志输出
#ifdef ANDROID
#include <android/log.h>
#define ANDROID_LOG_TAG "DOUBANGO"
#define ANDROID_DEBUG_INFO(fmt, ...) __android_log_print(ANDROID_LOG_INFO, ANDROID_LOG_TAG, fmt, ##__VA_ARGS__)
#define ANDROID_DEBUG_ERROR(fmt, ...) __android_log_print(ANDROID_LOG_ERROR, ANDROID_LOG_TAG, fmt, ##__VA_ARGS__)
#else
#define ANDROID_DEBUG_INFO(fmt, ...)
#define ANDROID_DEBUG_ERROR(fmt, ...)
#endif

static tsk_object_t* tsip_transac_dst_ctor(tsk_object_t * _self, va_list * app)
{
    tsip_transac_dst_t *dst = _self;
    if(dst) {

    }
    return _self;
}
static tsk_object_t* tsip_transac_dst_dtor(tsk_object_t * _self)
{
    tsip_transac_dst_t *dst = _self;
    if(dst) {
        TSK_OBJECT_SAFE_FREE(dst->stack);
        switch(dst->type) {
        case tsip_transac_dst_type_dialog: {
            TSK_OBJECT_SAFE_FREE(dst->dialog.dlg);
            break;
        }
        case tsip_transac_dst_type_net: {
            break;
        }
        }
    }
    return _self;
}
static const tsk_object_def_t tsip_transac_dst_def_s = {
    sizeof(tsip_transac_dst_t),
    tsip_transac_dst_ctor,
    tsip_transac_dst_dtor,
    tsk_null,
};
const tsk_object_def_t *tsip_transac_dst_def_t = &tsip_transac_dst_def_s;

static struct tsip_transac_dst_s* tsip_transac_dst_create(tsip_transac_dst_type_t type, struct tsip_stack_s* stack)
{
    struct tsip_transac_dst_s* dst = tsk_object_new(tsip_transac_dst_def_t);
    if(dst) {
        dst->type = type;
        dst->stack = tsk_object_ref(stack);
    }
    return dst;
}

struct tsip_transac_dst_s* tsip_transac_dst_dialog_create(tsip_dialog_t *dlg)
{
    struct tsip_transac_dst_s* dst;
    if((dst =  tsip_transac_dst_create(tsip_transac_dst_type_dialog, TSIP_DIALOG_GET_STACK(dlg)))) {
        dst->dialog.dlg = tsk_object_ref(dlg);
    }
    return dst;
}

struct tsip_transac_dst_s* tsip_transac_dst_net_create(struct tsip_stack_s* stack)
{
    struct tsip_transac_dst_s* dst;
    if((dst =  tsip_transac_dst_create(tsip_transac_dst_type_net, stack))) {
    }
    return dst;
}

static int tsip_transac_dst_deliver(struct tsip_transac_dst_s* self, tsip_dialog_event_type_t event_type, const tsip_message_t *msg)
{
    if(!self) {
        TSK_DEBUG_ERROR("Invalid parameter");
        ANDROID_DEBUG_ERROR("Invalid parameter");
        return -1;
    }

    TSK_DEBUG_INFO("*** tsip_transac_dst_deliver() called ***");
    ANDROID_DEBUG_INFO("*** tsip_transac_dst_deliver() called ***");
    TSK_DEBUG_INFO("  - Destination Type: %d", self->type);
    ANDROID_DEBUG_INFO("  - Destination Type: %d", self->type);
    TSK_DEBUG_INFO("  - Event Type: %d", event_type);
    ANDROID_DEBUG_INFO("  - Event Type: %d", event_type);

    switch(self->type) {
    case tsip_transac_dst_type_dialog: {
        TSK_DEBUG_INFO("  - Delivering to dialog callback");
        ANDROID_DEBUG_INFO("  - Delivering to dialog callback");
        int ret = self->dialog.dlg->callback(
                   self->dialog.dlg,
                   event_type,
                   msg
               );
        TSK_DEBUG_INFO("  - Dialog callback returned: %d", ret);
        ANDROID_DEBUG_INFO("  - Dialog callback returned: %d", ret);
        return ret;
    }
    case tsip_transac_dst_type_net: {
        if(!msg) {
            TSK_DEBUG_ERROR("Message is null");
            ANDROID_DEBUG_ERROR("Message is null");
            return -1;
        }

        TSK_DEBUG_INFO("  - Delivering to network transport");
        ANDROID_DEBUG_INFO("  - Delivering to network transport");
        
        // all messages coming from WebSocket transport have to be updated (AoR, Via...) before network delivering
        // all other messages MUST not unless specified from the dialog layer
        TSIP_MESSAGE(msg)->update |= (TNET_SOCKET_TYPE_IS_WS(msg->src_net_type) || TNET_SOCKET_TYPE_IS_WSS(msg->src_net_type));

        const char* branch = msg->firstVia ? msg->firstVia->branch : tsk_null;
        TSK_DEBUG_INFO("  - Using branch: %s", branch ? branch : "NULL");
        ANDROID_DEBUG_INFO("  - Using branch: %s", branch ? branch : "NULL");
        
        int ret = tsip_transport_layer_send(
                   self->stack->layer_transport,
                   branch,
                   TSIP_MESSAGE(msg)
               );
        TSK_DEBUG_INFO("  - Transport layer send returned: %d", ret);
        ANDROID_DEBUG_INFO("  - Transport layer send returned: %d", ret);
        return ret;
    }
    default: {
        TSK_DEBUG_ERROR("Unexpected destination type: %d", self->type);
        ANDROID_DEBUG_ERROR("Unexpected destination type: %d", self->type);
        return -2;
    }
    }
}


int tsip_transac_init(tsip_transac_t *self, tsip_transac_type_t type, int32_t cseq_value, const char* cseq_method, const char* callid, struct tsip_transac_dst_s* dst, tsk_fsm_state_id curr, tsk_fsm_state_id term)
{
    if(self && !self->initialized) {
        self->type = type;
        self->cseq_value = cseq_value;
        tsk_strupdate(&self->cseq_method, cseq_method);
        tsk_strupdate(&self->callid, callid);
        self->dst = tsk_object_ref(dst);

        /* FSM */
        self->fsm = tsk_fsm_create(curr, term);

        self->initialized = tsk_true;

        return 0;
    }
    return -1;
}

int tsip_transac_deinit(tsip_transac_t *self)
{
    if(self && self->initialized) {
        /* FSM */
        TSK_OBJECT_SAFE_FREE(self->fsm);

        TSK_FREE(self->branch);
        TSK_FREE(self->cseq_method);
        TSK_FREE(self->callid);
        TSK_OBJECT_SAFE_FREE(self->dst);

        self->initialized = tsk_false;

        return 0;
    }
    return -1;
}

int tsip_transac_start(tsip_transac_t *self, const tsip_request_t* request)
{
    if(!self) {
        TSK_DEBUG_ERROR("Invalid parameter");
        ANDROID_DEBUG_ERROR("Invalid parameter");
        return -1;
    }

    TSK_DEBUG_INFO("*** tsip_transac_start() called ***");
    ANDROID_DEBUG_INFO("*** tsip_transac_start() called ***");
    TSK_DEBUG_INFO("  - Transaction Type: %d", self->type);
    ANDROID_DEBUG_INFO("  - Transaction Type: %d", self->type);
    
    if(request) {
        TSK_DEBUG_INFO("  - Request Method: %s", request->line.request.method ? request->line.request.method : "NULL");
        ANDROID_DEBUG_INFO("  - Request Method: %s", request->line.request.method ? request->line.request.method : "NULL");
        if(request->line.request.uri && request->line.request.uri->host) {
            TSK_DEBUG_INFO("  - Request URI: %s", request->line.request.uri->host);
            ANDROID_DEBUG_INFO("  - Request URI: %s", request->line.request.uri->host);
        }
    }

    int ret = -2;
    switch(self->type) {
    case tsip_transac_type_nist: {
        TSK_DEBUG_INFO("  - Starting NIST transaction");
        ANDROID_DEBUG_INFO("  - Starting NIST transaction");
        ret = tsip_transac_nist_start(TSIP_TRANSAC_NIST(self), request);
        break;
    }
    case tsip_transac_type_ist: {
        TSK_DEBUG_INFO("  - Starting IST transaction");
        ANDROID_DEBUG_INFO("  - Starting IST transaction");
        ret = tsip_transac_ist_start(TSIP_TRANSAC_IST(self), request);
        break;
    }
    case tsip_transac_type_nict: {
        TSK_DEBUG_INFO("  - Starting NICT transaction");
        ANDROID_DEBUG_INFO("  - Starting NICT transaction");
        ret = tsip_transac_nict_start(TSIP_TRANSAC_NICT(self), request);
        break;
    }
    case tsip_transac_type_ict: {
        TSK_DEBUG_INFO("  - Starting ICT transaction");
        ANDROID_DEBUG_INFO("  - Starting ICT transaction");
        ret = tsip_transac_ict_start(TSIP_TRANSAC_ICT(self), request);
        break;
    }
    default: {
        TSK_DEBUG_ERROR("Unexpected transaction type: %d", self->type);
        ANDROID_DEBUG_ERROR("Unexpected transaction type: %d", self->type);
        break;
    }
    }
    
    TSK_DEBUG_INFO("  - Transaction start result: %d", ret);
    ANDROID_DEBUG_INFO("  - Transaction start result: %d", ret);
    return ret;
}

// deliver the message to the destination (e.g. local dialog)
int tsip_transac_deliver(tsip_transac_t* self, tsip_dialog_event_type_t event_type, const tsip_message_t *msg)
{
    if(!self) {
        TSK_DEBUG_ERROR("Invalid parameter");
        ANDROID_DEBUG_ERROR("Invalid parameter");
        return -1;
    }
    
    TSK_DEBUG_INFO("*** tsip_transac_deliver() called ***");
    ANDROID_DEBUG_INFO("*** tsip_transac_deliver() called ***");
    TSK_DEBUG_INFO("  - Event Type: %d", event_type);
    ANDROID_DEBUG_INFO("  - Event Type: %d", event_type);
    
    if(msg) {
        if(TSIP_MESSAGE_IS_RESPONSE(msg)) {
            tsip_response_t* response = TSIP_RESPONSE(msg);
            TSK_DEBUG_INFO("  - Delivering RESPONSE: %d %s", 
                          response->line.response.status_code,
                          response->line.response.reason_phrase ? response->line.response.reason_phrase : "NULL");
            ANDROID_DEBUG_INFO("  - Delivering RESPONSE: %d %s", 
                              response->line.response.status_code,
                              response->line.response.reason_phrase ? response->line.response.reason_phrase : "NULL");
        } else if(TSIP_MESSAGE_IS_REQUEST(msg)) {
            tsip_request_t* request = TSIP_REQUEST(msg);
            TSK_DEBUG_INFO("  - Delivering REQUEST: %s", 
                          request->line.request.method ? request->line.request.method : "NULL");
            ANDROID_DEBUG_INFO("  - Delivering REQUEST: %s", 
                              request->line.request.method ? request->line.request.method : "NULL");
        }
    }
    
    int ret = tsip_transac_dst_deliver(self->dst, event_type, msg);
    TSK_DEBUG_INFO("  - Delivery result: %d", ret);
    ANDROID_DEBUG_INFO("  - Delivery result: %d", ret);
    return ret;
}

// send the message over the network
int tsip_transac_send(tsip_transac_t *self, const char *branch, tsip_message_t *msg)
{
    TSK_DEBUG_INFO("*** tsip_transac_send() called ***");
    ANDROID_DEBUG_INFO("*** tsip_transac_send() called ***");
    
    if(self && TSIP_TRANSAC_GET_STACK(self)->layer_transport && msg) {
        const struct tsip_ssession_s* ss = TSIP_TRANSAC_GET_SESSION(self);
        
        TSK_DEBUG_INFO("Transaction Send Details:");
        ANDROID_DEBUG_INFO("Transaction Send Details:");
        TSK_DEBUG_INFO("  - Transaction Branch: %s", branch ? branch : "NULL");
        ANDROID_DEBUG_INFO("  - Transaction Branch: %s", branch ? branch : "NULL");
        TSK_DEBUG_INFO("  - Transaction Type: %d", self->type);
        ANDROID_DEBUG_INFO("  - Transaction Type: %d", self->type);
        TSK_DEBUG_INFO("  - Transaction Reliable: %s", self->reliable ? "YES" : "NO");
        ANDROID_DEBUG_INFO("  - Transaction Reliable: %s", self->reliable ? "YES" : "NO");
        
        if(msg) {
            if(TSIP_MESSAGE_IS_RESPONSE(msg)) {
                tsip_response_t* response = TSIP_RESPONSE(msg);
                TSK_DEBUG_INFO("  - Message Type: RESPONSE");
                ANDROID_DEBUG_INFO("  - Message Type: RESPONSE");
                TSK_DEBUG_INFO("  - Status Code: %d", response->line.response.status_code);
                ANDROID_DEBUG_INFO("  - Status Code: %d", response->line.response.status_code);
                TSK_DEBUG_INFO("  - Reason Phrase: %s", response->line.response.reason_phrase ? response->line.response.reason_phrase : "NULL");
                ANDROID_DEBUG_INFO("  - Reason Phrase: %s", response->line.response.reason_phrase ? response->line.response.reason_phrase : "NULL");
            } else if(TSIP_MESSAGE_IS_REQUEST(msg)) {
                tsip_request_t* request = TSIP_REQUEST(msg);
                TSK_DEBUG_INFO("  - Message Type: REQUEST");
                ANDROID_DEBUG_INFO("  - Message Type: REQUEST");
                TSK_DEBUG_INFO("  - Method: %s", request->line.request.method ? request->line.request.method : "NULL");
                ANDROID_DEBUG_INFO("  - Method: %s", request->line.request.method ? request->line.request.method : "NULL");
                if(request->line.request.uri && request->line.request.uri->host) {
                    TSK_DEBUG_INFO("  - URI Host: %s", request->line.request.uri->host);
                    ANDROID_DEBUG_INFO("  - URI Host: %s", request->line.request.uri->host);
                }
            }
            
            // 打印网络信息
            TSK_DEBUG_INFO("  - Network Info:");
            ANDROID_DEBUG_INFO("  - Network Info:");
            TSK_DEBUG_INFO("    - Local FD: %d", msg->local_fd);
            ANDROID_DEBUG_INFO("    - Local FD: %d", msg->local_fd);
            TSK_DEBUG_INFO("    - Source Net Type: %d", msg->src_net_type);
            ANDROID_DEBUG_INFO("    - Source Net Type: %d", msg->src_net_type);
            
            // 打印 Via 头信息（包含目标地址）
            if(msg->firstVia) {
                TSK_DEBUG_INFO("    - Via Host: %s", msg->firstVia->host ? msg->firstVia->host : "NULL");
                ANDROID_DEBUG_INFO("    - Via Host: %s", msg->firstVia->host ? msg->firstVia->host : "NULL");
                TSK_DEBUG_INFO("    - Via Port: %d", msg->firstVia->port);
                ANDROID_DEBUG_INFO("    - Via Port: %d", msg->firstVia->port);
                
                if(msg->firstVia->transport) {
                    TSK_DEBUG_INFO("    - Via Transport: %s", msg->firstVia->transport);
                    ANDROID_DEBUG_INFO("    - Via Transport: %s", msg->firstVia->transport);
                }
            }
            
            // 打印 Call-ID 用于跟踪
            if(msg->Call_ID && msg->Call_ID->value) {
                TSK_DEBUG_INFO("    - Call-ID: %s", msg->Call_ID->value);
                ANDROID_DEBUG_INFO("    - Call-ID: %s", msg->Call_ID->value);
            }
            
            // 打印 CSeq 信息
            if(msg->CSeq) {
                TSK_DEBUG_INFO("    - CSeq: %u %s", msg->CSeq->seq, msg->CSeq->method ? msg->CSeq->method : "NULL");
                ANDROID_DEBUG_INFO("    - CSeq: %u %s", msg->CSeq->seq, msg->CSeq->method ? msg->CSeq->method : "NULL");
            }
            
            // 打印内容信息
            if(TSIP_MESSAGE_HAS_CONTENT(msg)) {
                const tsk_buffer_t* content = TSIP_MESSAGE_CONTENT(msg);
                const char* content_type = TSIP_MESSAGE_CONTENT_TYPE(msg);
                TSK_DEBUG_INFO("    - Content-Type: %s", content_type ? content_type : "NULL");
                ANDROID_DEBUG_INFO("    - Content-Type: %s", content_type ? content_type : "NULL");
                TSK_DEBUG_INFO("    - Content-Length: %zu", content ? content->size : 0);
                ANDROID_DEBUG_INFO("    - Content-Length: %zu", content ? content->size : 0);
                
                // 打印消息内容（如果内容不太大）
                if(content && content->size > 0 && content->size < 500) {
                    TSK_DEBUG_INFO("    - Content: %.*s", (int)content->size, (char*)content->data);
                    ANDROID_DEBUG_INFO("    - Content: %.*s", (int)content->size, (char*)content->data);
                }
            } else {
                TSK_DEBUG_INFO("    - No Content");
                ANDROID_DEBUG_INFO("    - No Content");
            }
        }
        
        if(ss) {
            // set SigComp identifier as the message is directly sent to the transport layer
            tsk_strupdate(&msg->sigcomp_id, ss->sigcomp_id);
            TSK_DEBUG_INFO("  - SigComp ID: %s", ss->sigcomp_id ? ss->sigcomp_id : "NULL");
            ANDROID_DEBUG_INFO("  - SigComp ID: %s", ss->sigcomp_id ? ss->sigcomp_id : "NULL");
        }
        
        TSK_DEBUG_INFO("Sending message to transport layer...");
        ANDROID_DEBUG_INFO("Sending message to transport layer...");
        int ret = tsip_transport_layer_send(TSIP_TRANSAC_GET_STACK(self)->layer_transport, branch, TSIP_MESSAGE(msg));
        TSK_DEBUG_INFO("Transport layer send returned: %d", ret);
        ANDROID_DEBUG_INFO("Transport layer send returned: %d", ret);
        return ret;
    }
    TSK_DEBUG_ERROR("Invalid parameter: self=%p, transport=%p, msg=%p", 
                   self, 
                   self ? TSIP_TRANSAC_GET_STACK(self)->layer_transport : NULL, 
                   msg);
    ANDROID_DEBUG_ERROR("Invalid parameter: self=%p, transport=%p, msg=%p", 
                       self, 
                       self ? TSIP_TRANSAC_GET_STACK(self)->layer_transport : NULL, 
                       msg);
    return -1;
}

int tsip_transac_cmp(const tsip_transac_t *t1, const tsip_transac_t *t2)
{
    if(t1 && t2) {
        if(tsk_strequals(t1->branch, t2->branch) && tsk_strequals(t1->cseq_method, t2->cseq_method)) {
            return 0;
        }
    }
    return -1;
}

int tsip_transac_remove(const tsip_transac_t* self)
{
    int ret;
    tsip_transac_t* safe_copy;

    TSK_DEBUG_INFO("*** tsip_transac_remove() called ***");
    ANDROID_DEBUG_INFO("*** tsip_transac_remove() called ***");
    
    if(self) {
        TSK_DEBUG_INFO("  - Removing transaction type: %d", self->type);
        ANDROID_DEBUG_INFO("  - Removing transaction type: %d", self->type);
        TSK_DEBUG_INFO("  - Transaction branch: %s", self->branch ? self->branch : "NULL");
        ANDROID_DEBUG_INFO("  - Transaction branch: %s", self->branch ? self->branch : "NULL");
    }

    safe_copy = (tsip_transac_t*)tsk_object_ref(TSK_OBJECT(self));
    ret = tsip_transac_layer_remove(TSIP_TRANSAC_GET_STACK(self)->layer_transac, safe_copy);
    tsk_object_unref(safe_copy);

    TSK_DEBUG_INFO("  - Transaction remove result: %d", ret);
    ANDROID_DEBUG_INFO("  - Transaction remove result: %d", ret);
    return ret;
}

int tsip_transac_fsm_act(tsip_transac_t* self, tsk_fsm_action_id action_id, const tsip_message_t* message)
{
    int ret;
    tsip_transac_t* safe_copy;

    if(!self || !self->fsm) {
        TSK_DEBUG_WARN("Invalid parameter.");
        ANDROID_DEBUG_ERROR("Invalid parameter for tsip_transac_fsm_act");
        return -1;
    }

    TSK_DEBUG_INFO("*** tsip_transac_fsm_act() called ***");
    ANDROID_DEBUG_INFO("*** tsip_transac_fsm_act() called ***");
    TSK_DEBUG_INFO("  - Action ID: %d", action_id);
    ANDROID_DEBUG_INFO("  - Action ID: %d", action_id);
    TSK_DEBUG_INFO("  - Transaction Type: %d", self->type);
    ANDROID_DEBUG_INFO("  - Transaction Type: %d", self->type);

    safe_copy = tsk_object_ref(TSK_OBJECT(self));
    ret = tsk_fsm_act(self->fsm, action_id, safe_copy, message, self, message);
    tsk_object_unref(safe_copy);

    TSK_DEBUG_INFO("  - FSM action result: %d", ret);
    ANDROID_DEBUG_INFO("  - FSM action result: %d", ret);
    return ret;
}
