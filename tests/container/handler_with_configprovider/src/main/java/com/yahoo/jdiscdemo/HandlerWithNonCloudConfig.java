// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.jdiscdemo;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;

public class HandlerWithNonCloudConfig extends AbstractRequestHandler {

    private final String response;

    public HandlerWithNonCloudConfig(MyResponseConfig config) {
        response = config.getResponse();

        System.out.println(">>> Handler has response: " + response);
    }

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        FastContentWriter writer = ResponseDispatch.newInstance(Response.Status.OK).connectFastWriter(handler);
        writer.write(response);
        writer.close();
        return null;
    }
}
