FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN go mod tidy && go build -o /app .

FROM alpine:3.20
COPY --from=build /app /app
EXPOSE 8080
CMD ["/app"]
